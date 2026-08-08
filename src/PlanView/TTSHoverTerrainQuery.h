#pragma once
#include <QObject>
#include <QtPositioning/QGeoCoordinate>
#include "TerrainQuery.h"

/// TTS: غلاف بسيط حول TerrainAtCoordinateQuery عشان يقدر QML يستخدمه مباشرة —
/// TerrainAtCoordinateQuery نفسه كونستركتوره يطلب bool (autoDelete)، فما يصير
/// نسجّله لـ QML مباشرة (QML يحتاج كونستركتور بدون معاملات). هذا الغلاف يوفر
/// كونستركتور افتراضي + دالة/إشارة مبسّطة لنقطة واحدة (لاستخدام صندوق إحداثيات
/// الماوس الحي بـ PlanView.qml). نفس نمط FileWriter.h بالضبط.
///
/// TTS (تحديث): قبل اللجوء لاستعلام الشبكة غير المتزامن (بطيء، ~500ms+ حسب
/// السرعة)، نجرب أولاً TerrainAtCoordinateQuery::getAltitudesForCoordinates()
/// الثابتة (static) — هذي تُرجع النتيجة فوراً ومتزامنة لو الإحداثية موجودة
/// أصلاً بكاش التضاريس المحلي (مؤكد من التعليق بـ TerrainQuery.h: "Either
/// returns altitudes from cache or queues database request"). هذا يعطي نفس
/// سلوك Mission Planner: أول مرور فوق منطقة بطيء (تحميل من السيرفر)، وأي
/// مرور بعده فوق نفس المنطقة يكون فوري (من الكاش).
class TTSHoverTerrainQuery : public QObject
{
    Q_OBJECT
public:
    explicit TTSHoverTerrainQuery(QObject *parent = nullptr);
    ~TTSHoverTerrainQuery();
                              /// يطلب ارتفاع الأرض عند إحداثية واحدة (lat, lon). لو متوفرة بالكاش
                              /// المحلي، النتيجة توصل فوراً (بنفس الاستدعاء تقريباً). غير كذا،
                              /// النتيجة توصل لاحقاً بشكل غير متزامن عبر الإشارة terrainAltitudeReceived.
    Q_INVOKABLE void requestAltitude(double latitude, double longitude);
signals:
    /// success: نجح الاستعلام أو لا. altitude: بالمتر (AMSL)، صالحة بس لو success=true.
    void terrainAltitudeReceived(bool success, double altitude);
private:
    TerrainAtCoordinateQuery *_query = nullptr;
};