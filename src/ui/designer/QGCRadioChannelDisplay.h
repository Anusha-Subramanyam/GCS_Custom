#ifndef QGCRADIOCHANNELDISPLAY_H
#define QGCRADIOCHANNELDISPLAY_H

#include <QGroupBox>

class QGCRadioChannelDisplay : public QGroupBox
{
    Q_OBJECT
    
public:
    explicit QGCRadioChannelDisplay(QWidget *parent = 0);
    void setOrientation(Qt::Orientation orient);
    
    /// @brief Set the current RC value to display
    void setValue(int value);
    
    /// @brief Set the current RC Value, Minimum RC Value and Maximum RC Value
    void setValueAndRange(int val, int min, int max);
    
    void setMinMax(int min, int max);
    
    void setMin(int value);
    void setMax(int value);
    
    /// @brief Sets the Trim value for the channel
    void setTrim(int value);
    void setName(QString name);
    int value(void) { return _value; }
    int min(void) { return _min; }
    int max(void) { return _max; }
    int trim(void) { return _trim; }

    void showMinMax(bool show);
    bool isMinMaxShown() { return _showMinMax; }
    
    void showTrim(bool show);
    bool isTrimShown() { return _showTrim; }
    
protected:
    void paintEvent(QPaintEvent *event);
    
private:
    void _drawValuePointer(QPainter* painter, int xTip, int yTip, int height, bool rightSideUp);
    
    Qt::Orientation _orientation;
    
    int _value;         ///< Current RC value
    int _min;           ///< Min RC value
    int _max;           ///< Max RC value
    int _trim;          ///< RC Value for Trim position
    
    bool _showMinMax;   ///< true: show min max values on display
    bool _showTrim;     ///< true: show trim value on display
    
    QString _name;      ///< Channel name to display
    
    static const int _centerValue = 1500;                           ///< RC Value which is at center
    static const int _maxDeltaRange = 700;                          ///< Delta around center value which is the max range for widget
    static const int _minRange = _centerValue - _maxDeltaRange;     ///< Smallest value widget can display
    static const int _maxRange = _centerValue + _maxDeltaRange;     ///< Largest value widget can display
};

#endif // QGCRADIOCHANNELDISPLAY_H
