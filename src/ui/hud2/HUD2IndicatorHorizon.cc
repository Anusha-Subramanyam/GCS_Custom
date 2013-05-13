#include <QtGui>
#include <QSettings>

#include "HUD2Drawer.h"
#include "HUD2IndicatorHorizon.h"
#include "HUD2Math.h"

HUD2IndicatorHorizon::HUD2IndicatorHorizon(const float *pitch, const float *roll, QWidget *parent) :
    QWidget(parent),
    pitchline(&this->gap, this),
    crosshair(&this->gap, this),
    pitch(pitch),
    roll(roll)
{
    QColor color;
    QSettings settings;
    settings.beginGroup("QGC_HUD2");

    this->gap = 6;
    this->pitchcount = 5;
    this->degstep = 20;

    color = settings.value("INSTRUMENTS_COLOR", INSTRUMENTS_COLOR_DEFAULT).value<QColor>();
    this->pen.setColor(color);
    pitchline.setColor(color);
    crosshair.setColor(color);

    color = settings.value("SKY_COLOR", SKY_COLOR_DEFAULT).value<QColor>();
    skyPen   = QPen(color);
    skyBrush = QBrush(color);

    color = settings.value("GND_COLOR", GND_COLOR_DEFAULT).value<QColor>();
    gndPen   = QPen(color);
    gndBrush = QBrush(color);

    coloredBackground = settings.value("HORIZON_COLORED_BG", true).toBool();;

    settings.endGroup();
}

void HUD2IndicatorHorizon::updateGeometry(const QSize &size){
    int a = percent2pix_w(size, this->gap);

    // wings
    int x1 = size.width() / 2;
    int tmp = percent2pix_h(size, 1);
    hud2_clamp(tmp, 2, 10);
    pen.setWidth(tmp);
    hirizonleft.setLine(-x1, 0, -a, 0);
    horizonright.setLine(a, 0, x1, 0);

    // pitchlines
    pixstep = size.height() / pitchcount;
    pitchline.updateGeometry(size);

    // crosshair
    crosshair.updateGeometry(size);
}

/**
 * @brief drawpitchlines
 * @param painter
 * @param degstep
 * @param pixstep
 */
void HUD2IndicatorHorizon::drawpitchlines(QPainter *painter, qreal degstep, qreal pixstep){

    painter->save();
    int i = 0;
    while (i > -360){
        i -= degstep;
        painter->translate(0, -pixstep);
        pitchline.paint(painter, -i);
    }
    painter->restore();

    painter->save();
    i = 0;
    while (i < 360){
        i += degstep;
        painter->translate(0, pixstep);
        pitchline.paint(painter, -i);
    }
    painter->restore();
}

static int _getline_y(QPoint p1, QPoint p2, int x){
    int x1 = p1.rx();
    int y1 = p1.ry();
    int x2 = p2.rx();
    int y2 = p2.ry();

    return ((x2*y1 - x1*y2) + x * (y2 - y1)) / (x2 -x1);
}

void HUD2IndicatorHorizon::paint(QPainter *painter){

    qreal pitch_ = rad2deg(-*pitch);
    qreal delta_y = pitch_ * (pixstep / degstep);
    qreal delta_x = tan(-*roll) * delta_y;

    // create complex transfomation
    QPoint center = painter->window().center();
    QTransform transform;
    transform.translate(center.x(), center.y());
    transform.translate(delta_x, delta_y);
    transform.rotate(rad2deg(*roll));

    if (coloredBackground){
        // draw colored background
        /* some kind of hack to create poligon with minimal needed area:
         * - create rectangle
         * - apply transform to it
         * - from output polygon got points laying on horizon line
         * - use line formulae to calculate points of new polygon
         */

        painter->save();
        QRect rect = QRect(QPoint(-1000,0), QPoint(1000,1000));
        QPolygon poly = transform.mapToPolygon(rect);

        int x = 0;
        int w = painter->window().width();
        int h = painter->window().height();
        QPoint point_left = QPoint(x, _getline_y(poly.point(0), poly.point(1), x));
        x = w;
        QPoint point_right = QPoint(x, _getline_y(poly.point(0), poly.point(1), x));

        poly.setPoint(0, point_left);
        poly.setPoint(1, point_right);
        poly.setPoint(2, w, 0);
        poly.setPoint(3, 0, 0);

        painter->setBrush(skyBrush);
        painter->setPen(skyPen);
        painter->drawPolygon(poly);

        poly.setPoint(2, w, h);
        poly.setPoint(3, 0, h);
        painter->setBrush(gndBrush);
        painter->setPen(gndPen);
        painter->drawPolygon(poly);

        painter->restore();
    }

    // draw other stuff
    painter->save();
    painter->setTransform(transform);

    // pitchlines
    this->drawpitchlines(painter, degstep, pixstep);

    // horizon lines
    painter->setPen(pen);
    painter->drawLine(hirizonleft);
    painter->drawLine(horizonright);

    painter->restore();

    // central cross
    crosshair.paint(painter);
}

void HUD2IndicatorHorizon::setColor(QColor color){
    pen.setColor(color);
    pitchline.setColor(color);
    crosshair.setColor(color);
}

void HUD2IndicatorHorizon::setSkyColor(QColor color){
    skyPen.setColor(color);
    skyBrush.setColor(color);
}

void HUD2IndicatorHorizon::setGndColor(QColor color){
    gndPen.setColor(color);
    gndBrush.setColor(color);
}


