#include "FileWriter.h"

#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDir>
#include <QUrl>
#include <QDebug>
#include <QtQml>

bool FileWriter::save(const QString &filePath, const QString &text) const
{
    QString path = filePath;

            // Handle file:// URLs properly (decodes %20 etc.)
    if (path.startsWith(QStringLiteral("file://"))) {
        QUrl url(path);
        path = url.toLocalFile();
    }

            // Ensure parent directory exists
    QFileInfo fi(path);
    QDir dir = fi.absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "FileWriter: cannot open" << path << file.errorString();
        return false;
    }

    QTextStream out(&file);
    out << text;
    file.close();

    qInfo() << "FileWriter: saved" << path << "(" << text.size() << "chars)";
    return true;
}

// Register FileWriter as a QML type at application startup
static void registerFileWriter()
{
    qmlRegisterType<FileWriter>("QGroundControl.PlanView", 1, 0, "FileWriter");
}
Q_COREAPP_STARTUP_FUNCTION(registerFileWriter)