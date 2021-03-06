#include "apkextractiontask.h"

#include <QUrl>
#include <QDebug>
#include <mcpelauncher/zip_extractor.h>
#include <mcpelauncher/minecraft_extract_utils.h>
#include <mcpelauncher/apkinfo.h>
#include "versionmanager.h"

ApkExtractionTask::ApkExtractionTask(QObject *parent) : QThread(parent) {
    connect(this, &QThread::started, this, &ApkExtractionTask::emitActiveChanged);
    connect(this, &QThread::finished, this, &ApkExtractionTask::emitActiveChanged);
    connect(this, &ApkExtractionTask::versionInformationObtained, this, &ApkExtractionTask::onVersionInformationObtained);
}

bool ApkExtractionTask::setSourceUrls(QList<QUrl> const& urls) {
    QStringList list;
    for (auto&& url : urls) {
        if (!url.isLocalFile()) {
            return false;
        }
        list.append(url.toLocalFile());
    }
    setSources(list);
    return true;
}

void ApkExtractionTask::run() {
    QTemporaryDir dir (versionManager()->getTempTemplate());
    try {
        std::string path = dir.path().toStdString();
        ApkInfo apkInfo;
        apkInfo.versionCode = 0;
        for (auto && source : sources()) {
            ZipExtractor extractor (source.toStdString());
            {
                auto manifest = extractor.readFile("AndroidManifest.xml");
                axml::AXMLFile manifestFile (manifest.data(), manifest.size());
                axml::AXMLParser manifestParser (manifestFile);
                ApkInfo capkInfo = ApkInfo::fromXml(manifestParser);
                if (!apkInfo.versionCode) {
                    apkInfo = capkInfo;
                } else if(apkInfo.versionCode != capkInfo.versionCode) {
                    throw std::runtime_error("Trying to extract multiple apks with different versionsCodes is forbidden");
                } else if(apkInfo.versionName.empty()) {
                    apkInfo.versionName = capkInfo.versionName;
                }
            }
            qDebug() << "Apk info: versionCode=" << apkInfo.versionCode
                    << " versionName=" << QString::fromStdString(apkInfo.versionName);

            extractor.extractTo(MinecraftExtractUtils::filterMinecraftFiles(path),
                    [this](size_t current, size_t max, ZipExtractor::FileHandle const&, size_t, size_t) {
                emit progress((float)  current / max);
            });
        }

        if (!MinecraftExtractUtils::checkMinecraftLibFile(path)) {
            emit error("The specified file is not compatible with the launcher\nYou may imported an arm (smartphone) apk on a non arm based PC");
        }

        QString targetDir = versionManager()->getDirectoryFor(apkInfo.versionName);
        qDebug() << "Moving " << dir.path() << " to " << targetDir;
        QDir(targetDir).removeRecursively();
        if (!QDir().rename(dir.path(), targetDir))
            throw std::runtime_error("rename failed");
        dir.setAutoRemove(false);
        emit versionInformationObtained(QDir(targetDir).dirName(), QString::fromStdString(apkInfo.versionName), apkInfo.versionCode);
    } catch (std::exception& e) {
        emit error(e.what());
        return;
    }

    emit finished();
}

void ApkExtractionTask::onVersionInformationObtained(const QString &directory, const QString &versionName, int versionCode) {
    versionManager()->addVersion(directory, versionName, versionCode);
}
