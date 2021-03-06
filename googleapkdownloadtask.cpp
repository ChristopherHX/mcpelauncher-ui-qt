#include "googleapkdownloadtask.h"
#include "googleplayapi.h"
#include "googleloginhelper.h"

GoogleApkDownloadTask::GoogleApkDownloadTask(QObject *parent) : QObject(parent), m_active(false) {
}

void GoogleApkDownloadTask::setPlayApi(GooglePlayApi *value) {
    Q_ASSERT(m_playApi == nullptr);
    m_playApi = value;
}

QStringList GoogleApkDownloadTask::filePaths() {
    QMutexLocker l (&fileMutex);
    QStringList list;
    for(auto&& file : files) {
        list.append(file->fileName());
    }
    return list;
}

void GoogleApkDownloadTask::start() {
    m_active.store(true);
    emit activeChanged();
    m_playApi->getApi()->delivery(m_packageName.toStdString(), m_versionCode, std::string())->call([this](playapi::proto::finsky::response::ResponseWrapper&& resp) {
        auto dd = resp.payload().deliveryresponse().appdeliverydata();
        if((dd.has_gzippeddownloadurl() ? dd.gzippeddownloadurl() : dd.downloadurl()) == "") {
            throw std::runtime_error("To use the download feature, Minecraft: Bedrock Edition has to be purchased on the Google Play Store.\nIf you are trying to download a beta version, please make sure you are in the Minecraft beta program on Google Play and then try again after a while (joining the program might take a while).");
        }
        startDownload(dd);
    }, [this](std::exception_ptr e) {
        try {
            std::rethrow_exception(e);
        } catch(std::exception& e) {
            emit error(e.what());
        }
        m_active.store(false);
        emit activeChanged();
    });
}

bool GoogleApkDownloadTask::curlDoZlibInflate(z_stream &zs, int file, char *data, size_t len, int flags) {
    char buf[4096];
    int ret;
    zs.avail_in = (uInt) len;
    zs.next_in = (unsigned char*) data;
    zs.avail_out = 0;
    while (zs.avail_out == 0) {
        zs.avail_out = 4096;
        zs.next_out = (unsigned char*) buf;
        ret = inflate(&zs, flags);
        if (ret == Z_STREAM_ERROR)
            return false;
        if (write(file, buf, sizeof(buf) - zs.avail_out) != sizeof(buf) - zs.avail_out)
            return false;
    }
    return true;
}

template<class T, class U> void GoogleApkDownloadTask::downloadFile(T const&dd, U cookie, std::function<void()> success, std::function<void()> _error, std::shared_ptr<DownloadProgress> _progress, size_t id) {
    auto file = std::make_shared<QTemporaryFile>();
    bool isGzipped = dd.has_gzippeddownloadurl();
    playapi::http_request req(isGzipped ? dd.gzippeddownloadurl() : dd.downloadurl());
    if(_progress->downloadsize != -1) {
        auto size = isGzipped ? dd.gzippeddownloadsize() : dd.downloadsize();
        if(size > 0) {
            _progress->downloadsize += size;
            _progress->progress[id] = 0;
        } else {
            _progress->downloadsize = -1;
        }
    }
    if (isGzipped)
        req.set_encoding("gzip,deflate");
    req.add_header("Accept-Encoding", "identity");
    req.add_header("Cookie", cookie.name() + "=" + cookie.value());
    auto& device = m_playApi->getLogin()->getDevice();
    req.set_user_agent("AndroidDownloadManager/" + device.build_version_string + " (Linux; U; Android " +
                       device.build_version_string + "; " + device.build_model + " Build/" + device.build_id + ")");
    req.set_follow_location(true);
    req.set_timeout(0L);

    if (!file->open())
        throw std::runtime_error("Failed to open file");
    int fd = file->handle();
    std::shared_ptr<z_stream> zs;
    if (isGzipped) {
        zs = std::make_shared<z_stream>();
        zs->zalloc = Z_NULL;
        zs->zfree = Z_NULL;
        zs->opaque = Z_NULL;
        int ret = inflateInit2(zs.get(), 31);
        if (ret != Z_OK)
            throw std::runtime_error("Failed to init zlib");

        req.set_custom_output_func([fd, zs](char* data, size_t size) {
            if (!curlDoZlibInflate(*zs, fd, data, size, Z_NO_FLUSH))
                return (size_t) 0;
            return size;
        });
    } else {
        req.set_custom_output_func([fd](char* data, size_t size) {
            return write(fd, data, size);
        });
    }

    req.set_progress_callback([this, _progress, id](curl_off_t dltotal, curl_off_t dlnow, curl_off_t ultotal, curl_off_t ulnow) {
        std::lock_guard<std::mutex> guard(_progress->mtx);
        if(_progress->downloadsize > 0) {
            _progress->progress[id] = dlnow;
            emit progress((float) std::accumulate(_progress->progress.begin(), _progress->progress.end(), 0) / _progress->downloadsize);
        }
    });
    emit progress(0.f);
    req.perform([this, file, zs, fd, isGzipped, success, _error](playapi::http_response resp) {
        if (isGzipped) {
            curlDoZlibInflate(*zs, fd, Z_NULL, 0, Z_FINISH);
            inflateEnd(zs.get());
        }
        file->close();
        if (resp) {
            if(resp.get_status_code() == 200) {
                {
                    QMutexLocker l (&fileMutex);
                    files.push_back(file);
                }
                success();
            } else {
                emit error(QString::fromStdString("Downloading file failed: Status[" + std::to_string(resp.get_status_code()) + "] '" + resp.get_body() + "'"));
                _error();
            }
        }
        else {
            emit error("CURL error");
            _error();
        }
    }, [this, file, zs, fd, isGzipped, _error](std::exception_ptr e) {
        if (isGzipped) {
            curlDoZlibInflate(*zs, fd, Z_NULL, 0, Z_FINISH);
            inflateEnd(zs.get());
        }
        file->close();

        try {
            std::rethrow_exception(e);
        } catch(std::exception& e) {
            emit error(e.what());
        }
        _error();
    });
}

void GoogleApkDownloadTask::startDownload(playapi::proto::finsky::download::AndroidAppDeliveryData const &dd) {
    auto cookie = dd.downloadauthcookie(0);
    auto progress = std::make_shared<DownloadProgress>();
    std::lock_guard<std::mutex> guard(progress->mtx);
    progress->downloads = 1 + dd.splitdeliverydata().Capacity();
    progress->progress.resize(progress->downloads);
    progress->downloadsize = 0;
    auto cleanup = [this, progress]() {
        std::lock_guard<std::mutex> guard(progress->mtx);
        if(!--progress->downloads) {
            m_active.store(false);
            emit activeChanged();
        }
    };
    auto success = [this, cleanup, dd, cookie, progress]() {
        std::lock_guard<std::mutex> guard(progress->mtx);
        if(!--progress->downloads) {
            m_active.store(false);
            emit activeChanged();
            emit finished();
        }
    };
    {
        QMutexLocker l (&fileMutex);
        files.clear();
    }
    size_t id = 0;
    downloadFile(dd, cookie, success, cleanup, progress, id++);
    for(auto && data : dd.splitdeliverydata()) {
        downloadFile(data, cookie, success, cleanup, progress, id++);
    }
    progress->downloads = id;
}
