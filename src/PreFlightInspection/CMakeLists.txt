# ============================================================================
# Pre-Flight Inspection Module
# Pre-flight checks, control surface test, manual checklist, readiness summary
# ============================================================================

qt_add_library(PreFlightInspectionModule STATIC)

# Shared enum / colour helper for the whole page.
set_source_files_properties(PreFlightStatus.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(PreFlightInspectionModule
    URI QGroundControl.PreFlightInspection
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        PreFlightInspectionPlanSection.qml
        PreFlightSectionCard.qml
        PreFlightStatus.qml
    NO_PLUGIN
)
