#pragma once
#include <QObject>
#include <QtPositioning/QGeoCoordinate>
#include "TerrainQuery.h"

/// TTS: غلاف بسيط حول TerrainAtCoordinateQuery عشان يقدر QML يستخدمه مباشرة —
/// TerrainAtCoordinateQuery نفسه كونستركتوره يطلب bool (autoDelete)، فما يصير
/// نسجّله لـ QML مباشرة (QML يحتاج كونستركتور بدون معاملات). هذا الغلاف يوفر
/// كونستركتور افتراضي + دالة/إشارة مبسّطة لنقطة واحدة (لاستخدام صندوق إحداثيات
/// الماوس الحي بـ PlanView.qml). نفس نمط FileWriter.h بالضبط.
class TTSHoverTerrainQuery : public QObject
{
    Q_OBJECT
public:
    explicit TTSHoverTerrainQuery(QObject *parent = nullptr);
    ~TTSHoverTerrainQuery();

            /// يطلب ارتفاع الأرض عند إحداثية واحدة (lat, lon). النتيجة توصل لاحقاً
            /// عبر الإشارة terrainAltitudeReceived — الاستعلام غير متزامن.
    Q_INVOKABLE void requestAltitude(double latitude, double longitude);

signals:
    /// success: نجح الاستعلام أو لا. altitude: بالمتر (AMSL)، صالحة بس لو success=true.
    void terrainAltitudeReceived(bool success, double altitude);

private:
    TerrainAtCoordinateQuery *_query = nullptr;
};