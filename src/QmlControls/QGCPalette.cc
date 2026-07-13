#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
                                          QObject(parent),
                                          _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

            // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    // ═══════════════════════════════════════════════════════════════════════
    //  TTS GROUP — Custom Dark Theme
    //  Light theme values are UNCHANGED (columns 1 & 2).
    //  Dark-Disabled (column 3) and Dark-Enabled (column 4) are TTS themed.
    //
    //  Palette reference:
    //    cBg        #0A0C0E     Main background
    //    cPanel     #111518     Panel / sidebar background
    //    cHeaderBg  #0D1114     Section header background
    //    cBorder    #1E2830     Borders
    //    cBorderHi  #2E4050     Highlighted borders / dividers
    //    cNeon      #00FF88     Primary accent (neon green)
    //    cNeonMid   #00CC6A     Secondary accent
    //    cWhite     #DDE5EA     Primary text
    //    cGrey      #4A6070     Secondary text / labels
    //    cGreyDim   #2A3840     Disabled elements
    //    cRed       #FF2244     Errors / critical
    //    cOrange    #FF6600     Warnings
    // ═══════════════════════════════════════════════════════════════════════

            //                                      Light                 Dark
            //                                      Disabled   Enabled    Disabled       Enabled
    DECLARE_QGC_COLOR(window,               "#ffffff", "#ffffff", "#0A0C0E",     "#111518")
    DECLARE_QGC_COLOR(windowTransparent,    "#ccffffff", "#ccffffff", "#cc0A0C0E", "#cc111518")
    DECLARE_QGC_COLOR(windowShadeLight,     "#909090", "#828282", "#2E4050",     "#2E4050")
    DECLARE_QGC_COLOR(windowShade,          "#d9d9d9", "#d9d9d9", "#0D1114",     "#0D1114")
    DECLARE_QGC_COLOR(windowShadeDark,      "#bdbdbd", "#bdbdbd", "#0A0C0E",     "#0A0C0E")
    DECLARE_QGC_COLOR(text,                 "#9d9d9d", "#333333", "#4A6070",     "#DDE5EA")
    DECLARE_QGC_COLOR(warningText,          "#cc0808", "#cc0808", "#FF2244",     "#FF2244")
    DECLARE_QGC_COLOR(button,               "#ffffff", "#ffffff", "#1E2830",     "#1E2830")
    DECLARE_QGC_COLOR(buttonBorder,         "#9d9d9d", "#3A9BDC", "#2E4050",     "#2E4050")
    DECLARE_QGC_COLOR(buttonText,           "#9d9d9d", "#333333", "#4A6070",     "#DDE5EA")
    DECLARE_QGC_COLOR(buttonHighlight,      "#e4e4e4", "#3A9BDC", "#0D1114",     "#116B43")
    DECLARE_QGC_COLOR(buttonHighlightText,  "#2c2c2c", "#ffffff", "#4A6070",     "#DDE5EA")
    DECLARE_QGC_COLOR(primaryButton,        "#585858", "#8cb3be", "#2A3840",     "#00CC6A")
    DECLARE_QGC_COLOR(primaryButtonText,    "#2c2c2c", "#333333", "#2A3840",     "#0A0C0E")
    DECLARE_QGC_COLOR(textField,            "#ffffff", "#ffffff", "#1E2830",     "#1E2830")
    DECLARE_QGC_COLOR(textFieldText,        "#808080", "#333333", "#4A6070",     "#DDE5EA")
    DECLARE_QGC_COLOR(mapButton,            "#585858", "#333333", "#0A0C0E",     "#0A0C0E")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#585858", "#be781c", "#2A3840",     "#00CC6A")
    DECLARE_QGC_COLOR(mapIndicator,         "#585858", "#be781c", "#2A3840",     "#00CC6A")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#585858", "#766043", "#2A3840",     "#3A4E5A")
    DECLARE_QGC_COLOR(colorGreen,           "#008f2d", "#008f2d", "#00CC6A",     "#00FF88")
    DECLARE_QGC_COLOR(colorYellow,          "#a2a200", "#a2a200", "#FFB800",     "#FFB800")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#799f26", "#799f26", "#00CC6A",     "#00CC6A")
    DECLARE_QGC_COLOR(colorOrange,          "#bf7539", "#bf7539", "#FF6600",     "#FF6600")
    DECLARE_QGC_COLOR(colorRed,             "#b52b2b", "#b52b2b", "#FF2244",     "#FF2244")
    DECLARE_QGC_COLOR(colorGrey,            "#808080", "#808080", "#4A6070",     "#4A6070")
    DECLARE_QGC_COLOR(colorBlue,            "#1a72ff", "#1a72ff", "#536dff",     "#536dff")
    DECLARE_QGC_COLOR(alertBackground,      "#eecc44", "#eecc44", "#FF6600",     "#FF6600")
    DECLARE_QGC_COLOR(alertBorder,          "#808080", "#808080", "#2E4050",     "#2E4050")
    DECLARE_QGC_COLOR(alertText,            "#000000", "#000000", "#0A0C0E",     "#0A0C0E")
    DECLARE_QGC_COLOR(missionItemEditor,    "#585858", "#dbfef8", "#0D1114",     "#0D1114")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#585858", "#9D9D9D", "#1E2830",     "#1E2830")
    DECLARE_QGC_COLOR(statusFailedText,     "#9d9d9d", "#000000", "#4A6070",     "#FF2244")
    DECLARE_QGC_COLOR(statusPassedText,     "#9d9d9d", "#000000", "#4A6070",     "#00FF88")
    DECLARE_QGC_COLOR(statusPendingText,    "#9d9d9d", "#000000", "#4A6070",     "#DDE5EA")
    DECLARE_QGC_COLOR(toolbarBackground,    "#00ffffff", "#00ffffff", "#0A0C0E",  "#0A0C0E")
    DECLARE_QGC_COLOR(groupBorder,          "#bbbbbb", "#3A9BDC", "#1E2830",     "#1E2830")
    DECLARE_QGC_COLOR(modifiedParamValue,   "#bf7539", "#bf7539", "#FF6600",     "#FF6600")

            // Colors not affecting by theming
            //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#4A2C6D", "#4A2C6D")
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#48D6FF", "#6045c5")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#4A6070", "#DDE5EA")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#4A6070", "#DDE5EA")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#FF2244", "#FF2244")

            // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#DDE5EA")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#0A0C0E")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#00FF88")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "#00CC6A")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "#FF2244")

}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}