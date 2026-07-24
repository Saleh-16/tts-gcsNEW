#include "TTSHoverTerrainQuery.h"

#include <QtQml>

TTSHoverTerrainQuery::TTSHoverTerrainQuery(QObject *parent)
    : QObject(parent)
{
    // autoDelete=false: إحنا نملك الكائن وندير عمره (نفس الكائن يُعاد استخدامه
    // لكل طلب جديد، مو ننشئ كائن جديد كل مرة الماوس يتحرك)
    _query = new TerrainAtCoordinateQuery(false, this);
    connect(_query, &TerrainAtCoordinateQuery::terrainDataReceived, this,
            [this](bool success, const QList<double> &heights) {
                double alt = (success && !heights.isEmpty()) ? heights.first() : 0.0;
                emit terrainAltitudeReceived(success, alt);
            });
}

TTSHoverTerrainQuery::~TTSHoverTerrainQuery()
{
    // _query مُنشأ بـ this كـ parent، فـ Qt يحذفه تلقائياً — لا حاجة لحذف يدوي
}

void TTSHoverTerrainQuery::requestAltitude(double latitude, double longitude)
{
    if (!_query) {
        return;
    }
    QGeoCoordinate coord(latitude, longitude);
    if (!coord.isValid()) {
        emit terrainAltitudeReceived(false, 0.0);
        return;
    }
    _query->requestData(QList<QGeoCoordinate>{coord});
}

// Register TTSHoverTerrainQuery as a QML type at application startup —
// نفس نمط FileWriter.cc بالضبط (Q_COREAPP_STARTUP_FUNCTION)
static void registerTTSHoverTerrainQuery()
{
    qmlRegisterType<TTSHoverTerrainQuery>("QGroundControl.PlanView", 1, 0, "TTSHoverTerrainQuery");
}
Q_COREAPP_STARTUP_FUNCTION(registerTTSHoverTerrainQuery)
