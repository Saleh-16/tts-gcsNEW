#pragma once

#include <QObject>

/// Tiny utility so QML can write a text file reliably.
class FileWriter : public QObject
{
    Q_OBJECT

public:
    explicit FileWriter(QObject *parent = nullptr) : QObject(parent) {}

            /// Write @p text to @p filePath.  Returns true on success.
    Q_INVOKABLE bool save(const QString &filePath, const QString &text) const;
};