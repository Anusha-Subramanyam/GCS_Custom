#include <QPainter>

#include "HUD2IndicatorCompass.h"
#include "HUD2Math.h"

HUD2IndicatorCompass::HUD2IndicatorCompass(const HUD2Data *huddata, QWidget *parent) :
    QWidget(parent),
    huddata(huddata)
{
    ribbon = new HUD2Ribbon(POSITION_TOP, this, true);
}

void HUD2IndicatorCompass::updateGeometry(const QSize &size){
    ribbon->updateGeometry(size);
}

void HUD2IndicatorCompass::paint(QPainter *painter){
    painter->save();
    ribbon->paint(painter, rad2deg(huddata->yaw));
    painter->restore();
}

void HUD2IndicatorCompass::setColor(QColor color){
    ribbon->setColor(color);
}
