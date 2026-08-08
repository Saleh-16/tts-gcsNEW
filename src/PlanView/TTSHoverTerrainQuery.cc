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

            // TTS: أولاً نجرب القراءة المتزامنة من الكاش المحلي — لو متوفرة، نرجعها
            // فوراً بدون انتظار أي استعلام شبكة (نفس سلوك Mission Planner للمناطق
            // اللي زارها المستخدم قبل كذا). التوقيع مؤكد من TerrainQuery.h:
            //   static bool getAltitudesForCoordinates(const QList<QGeoCoordinate> &coordinates,
            //                                           QList<double> &altitudes, bool &error);
            // ترجع true فقط لو القيم متوفرة فوراً من الكاش (تحقق من error كمان).
    QList<QGeoCoordinate> coords{coord};
    QList<double> altitudes;
    bool error = false;
    const bool immediateResult = TerrainAtCoordinateQuery::getAltitudesForCoordinates(coords, altitudes, error);

    if (immediateResult) {
        // متوفرة بالكاش — رد فوري بدون تأخير شبكة
        const bool success = !error && !altitudes.isEmpty();
        const double alt = success ? altitudes.first() : 0.0;
        emit terrainAltitudeReceived(success, alt);
        return;
    }

            // غير متوفرة بالكاش — نرجع لأسلوب الاستعلام غير المتزامن (بطيء أول مرة
            // بس، وبعدها تنزل بالكاش وتصير فورية بالمرات الجاية لنفس المنطقة)
    _query->requestData(coords);
}

// Register TTSHoverTerrainQuery as a QML type at application startup —
// نفس نمط FileWriter.cc بالضبط (Q_COREAPP_STARTUP_FUNCTION)
static void registerTTSHoverTerrainQuery()
{
    qmlRegisterType<TTSHoverTerrainQuery>("QGroundControl.PlanView", 1, 0, "TTSHoverTerrainQuery");
}
Q_COREAPP_STARTUP_FUNCTION(registerTTSHoverTerrainQuery)