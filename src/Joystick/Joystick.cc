/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "Joystick.h"
#include "QGC.h"
#include "AutoPilotPlugin.h"
#include "UAS.h"

#include <QSettings>

QGC_LOGGING_CATEGORY(JoystickLog, "JoystickLog")
QGC_LOGGING_CATEGORY(JoystickValuesLog, "JoystickValuesLog")

const char* Joystick::_settingsGroup =              "Joysticks";
const char* Joystick::_calibratedSettingsKey =      "Calibrated1"; // Increment number to force recalibration
const char* Joystick::_buttonActionSettingsKey =    "ButtonActionName%1";
const char* Joystick::_throttleModeSettingsKey =    "ThrottleMode";
const char* Joystick::_exponentialSettingsKey =     "Exponential";
const char* Joystick::_accumulatorSettingsKey =     "Accumulator";
const char* Joystick::_deadbandSettingsKey =        "Deadband";
const char* Joystick::_modeSettingsKey =            NULL;
const char* Joystick::_fixedWingModeSettingsKey =   "TXMode_FixedWing";
const char* Joystick::_multiRotorModeSettingsKey =  "TXMode_MultiRotor";
const char* Joystick::_roverModeSettingsKey =       "TXMode_Rover";
const char* Joystick::_vtolModeSettingsKey =        "TXMode_VTOL";
const char* Joystick::_submarineModeSettingsKey =   "TXMode_Submarine";

int Joystick::_mode = 2;

const char* Joystick::_rgAxisMappingKey[Joystick::maxAxis] = {
    "stickLeftXAxisIndex",
    "stickLeftYAxisIndex",
    "stickRightXAxisIndex",
    "stickRightYAxisIndex"
};

Joystick::Joystick(const QString& name, int axisCount, int buttonCount, int hatCount, MultiVehicleManager* multiVehicleManager)
    : _exitThread(false)
    , _name(name)
    , _axisCount(axisCount)
    , _buttonCount(buttonCount)
    , _hatCount(hatCount)
    , _hatButtonCount(4*hatCount)
    , _totalButtonCount(_buttonCount+_hatButtonCount)
    , _calibrationMode(CalibrationModeOff)
    , _rgAxisValues(NULL)
    , _rgCalibration(NULL)
    , _rgButtonValues(NULL)
    , _lastButtonBits(0)
    , _throttleMode(ThrottleModeCenterZero)
    , _exponential(false)
    , _accumulator(false)
    , _deadband(false)
    , _activeVehicle(NULL)
    , _pollingStartedForCalibration(false)
    , _multiVehicleManager(multiVehicleManager)
{

    _rgAxisValues = new int[_axisCount];
    _rgCalibration = new Calibration_t[_axisCount];
    _rgButtonValues = new bool[_totalButtonCount];

    for (int i=0; i<_axisCount; i++) {
        _rgAxisValues[i] = 0;
    }
    for (int i=0; i<_totalButtonCount; i++) {
        _rgButtonValues[i] = false;
    }

    _loadSettings();

    connect(_multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &Joystick::_activeVehicleChanged);
}

Joystick::~Joystick()
{
    delete _rgAxisValues;
    delete _rgCalibration;
    delete _rgButtonValues;
}

void Joystick::_setDefaultCalibration(void) {
    QSettings   settings;
    settings.beginGroup(_settingsGroup);
    settings.beginGroup(_name);
    _calibrated = settings.value(_calibratedSettingsKey, false).toBool();

    // Only set default calibrations if we do not have a calibration for this gamecontroller
    if(_calibrated) return;

    for (int axis=0; axis<_axisCount; axis++) {
        Joystick::Calibration_t calibration;
        _rgCalibration[axis] = calibration;
    }

    _rgCalibration[stickRightY].reversed = true;
    _rgCalibration[stickLeftY].reversed = true;

    for (int axis=0; axis<maxAxis; axis++) {
        _rgAxisMapping[axis] = axis;
    }

    setMode(2);

    _exponential = false;
    _accumulator = false;
    _deadband = false;
    _throttleMode = ThrottleModeCenterZero;
    _calibrated = true;

    _saveSettings();
}

void Joystick::_activeVehicleChanged(Vehicle *activeVehicle)
{
    if(activeVehicle) {
        if(activeVehicle->fixedWing()) {
            _modeSettingsKey = _fixedWingModeSettingsKey;
        } else if(activeVehicle->multiRotor()) {
            _modeSettingsKey = _multiRotorModeSettingsKey;
        } else if(activeVehicle->rover()) {
            _modeSettingsKey = _roverModeSettingsKey;
        } else if(activeVehicle->vtol()) {
            _modeSettingsKey = _vtolModeSettingsKey;
        } else if(activeVehicle->sub()) {
            _modeSettingsKey = _submarineModeSettingsKey;
        } else {
            _modeSettingsKey = NULL;
            qWarning() << "No valid joystick TXmode settings key for selected vehicle";
            return;
        }

        QSettings settings;
        settings.beginGroup(_settingsGroup);
        int mode = settings.value(_modeSettingsKey, activeVehicle->firmwarePlugin()->defaultJoystickTXMode()).toInt();

        setMode(mode, false);
    }
}

void Joystick::_loadSettings(void)
{
    QSettings   settings;

    settings.beginGroup(_settingsGroup);

    int mode = 2;
    if(_modeSettingsKey)
        mode = settings.value(_modeSettingsKey, 2).toInt();

    qCDebug(JoystickLog) << "_loadSettings Mode:" << mode;

    settings.beginGroup(_name);

    bool badSettings = false;
    bool convertOk;

    qCDebug(JoystickLog) << "_loadSettings Name:" << _name;

    _calibrated = settings.value(_calibratedSettingsKey, false).toBool();
    _exponential = settings.value(_exponentialSettingsKey, false).toBool();
    _accumulator = settings.value(_accumulatorSettingsKey, false).toBool();
    _deadband = settings.value(_deadbandSettingsKey, false).toBool();

    _throttleMode = (ThrottleMode_t)settings.value(_throttleModeSettingsKey, ThrottleModeCenterZero).toInt(&convertOk);
    badSettings |= !convertOk;

    qCDebug(JoystickLog) << "_loadSettings calibrated:throttlemode:exponential:deadband:badsettings" << _calibrated << _throttleMode << _exponential << _deadband << badSettings;

    QString minTpl  ("Axis%1Min");
    QString maxTpl  ("Axis%1Max");
    QString trimTpl ("Axis%1Trim");
    QString revTpl  ("Axis%1Rev");
    QString deadbndTpl  ("Axis%1Deadbnd");

    for (int axis=0; axis<_axisCount; axis++) {
        Calibration_t* calibration = &_rgCalibration[axis];

        calibration->center = settings.value(trimTpl.arg(axis), 0).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->min = settings.value(minTpl.arg(axis), -32768).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->max = settings.value(maxTpl.arg(axis), 32767).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->deadband = settings.value(deadbndTpl.arg(axis), 0).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->reversed = settings.value(revTpl.arg(axis), false).toBool();


        qCDebug(JoystickLog) << "_loadSettings axis:min:max:trim:reversed:deadband:badsettings" << axis << calibration->min << calibration->max << calibration->center << calibration->reversed << calibration->deadband << badSettings;
    }

    for (int axis=0; axis<maxAxis; axis++) {
        int mappedAxis;
        mappedAxis = settings.value(_rgAxisMappingKey[axis], -1).toInt(&convertOk);
        badSettings |= !convertOk || (mappedAxis == -1);

        _rgAxisMapping[axis] = mappedAxis;

        qCDebug(JoystickLog) << "_loadSettings axis:mappedAxis:badsettings" << axis << mappedAxis << badSettings;
    }

    for (int button=0; button<_totalButtonCount; button++) {
        _rgButtonActions << settings.value(QString(_buttonActionSettingsKey).arg(button), QString()).toString();
        qCDebug(JoystickLog) << "_loadSettings button:action" << button << _rgButtonActions[button];
    }

    if (badSettings) {
        _calibrated = false;
        settings.setValue(_calibratedSettingsKey, false);
    }

    setMode(mode, false); // defaults to 2
}

void Joystick::_saveSettings(void)
{
    QSettings settings;

    settings.beginGroup(_settingsGroup);

    // Mode is static
    settings.setValue(_modeSettingsKey, _mode);

    // Calibration settings for this particular joystick
    settings.beginGroup(_name);

    settings.setValue(_calibratedSettingsKey, _calibrated);
    settings.setValue(_exponentialSettingsKey, _exponential);
    settings.setValue(_accumulatorSettingsKey, _accumulator);
    settings.setValue(_deadbandSettingsKey, _deadband);
    settings.setValue(_throttleModeSettingsKey, _throttleMode);

    qCDebug(JoystickLog) << "_saveSettings calibrated:throttlemode:deadband:mode" << _calibrated << _throttleMode << _deadband << _mode;

    QString minTpl  ("Axis%1Min");
    QString maxTpl  ("Axis%1Max");
    QString trimTpl ("Axis%1Trim");
    QString revTpl  ("Axis%1Rev");
    QString deadbndTpl  ("Axis%1Deadbnd");

    for (int axis=0; axis<_axisCount; axis++) {
        Calibration_t* calibration = &_rgCalibration[axis];

        settings.setValue(trimTpl.arg(axis), calibration->center);
        settings.setValue(minTpl.arg(axis), calibration->min);
        settings.setValue(maxTpl.arg(axis), calibration->max);
        settings.setValue(revTpl.arg(axis), calibration->reversed);
        settings.setValue(deadbndTpl.arg(axis), calibration->deadband);

        qCDebug(JoystickLog) << "_saveSettings name:axis:min:max:trim:reversed:deadband"
                                << _name
                                << axis
                                << calibration->min
                                << calibration->max
                                << calibration->center
                                << calibration->reversed
                                << calibration->deadband;
    }

    for (int axis=0; axis<maxAxis; axis++) {
        settings.setValue(_rgAxisMappingKey[axis], _rgAxisMapping[axis]);
        qCDebug(JoystickLog) << "_saveSettings name:axis:mappedAxis" << _name << axis << _rgAxisMapping[axis];
    }

    for (int button=0; button<_totalButtonCount; button++) {
        settings.setValue(QString(_buttonActionSettingsKey).arg(button), _rgButtonActions[button]);
        qCDebug(JoystickLog) << "_saveSettings button:action" << button << _rgButtonActions[button];
    }
}

/// Adjust the raw axis value to the -1:1 range given calibration information
float Joystick::_adjustRange(int value, Calibration_t calibration, bool withDeadbands)
{
    float valueNormalized;
    float axisLength;
    float axisBasis;

    if (value > calibration.center) {
        axisBasis = 1.0f;
        valueNormalized = value - calibration.center;
        axisLength =  calibration.max - calibration.center;
    } else {
        axisBasis = -1.0f;
        valueNormalized = calibration.center - value;
        axisLength =  calibration.center - calibration.min;
    }

    if (withDeadbands) {
        if (valueNormalized>calibration.deadband) valueNormalized-=calibration.deadband;
        else if (valueNormalized<-calibration.deadband) valueNormalized+=calibration.deadband;
        else valueNormalized = 0.f;
    }

    float axisPercent = valueNormalized / axisLength;

    float correctedValue = axisBasis * axisPercent;

    if (calibration.reversed) {
        correctedValue *= -1.0f;
    }

#if 0
    qCDebug(JoystickLog) << "_adjustRange corrected:value:min:max:center:reversed:deadband:basis:normalized:length"
                            << correctedValue
                            << value
                            << calibration.min
                            << calibration.max
                            << calibration.center
                            << calibration.reversed
                            << calibration.deadband
                            << axisBasis
                            << valueNormalized
                            << axisLength;
#endif

    return std::max(-1.0f, std::min(correctedValue, 1.0f));
}


void Joystick::run(void)
{
    _open();

    while (!_exitThread) {
    _update();

        // Update axes
        for (int axisIndex=0; axisIndex<_axisCount; axisIndex++) {
            int newAxisValue = _getAxis(axisIndex);
            // Calibration code requires signal to be emitted even if value hasn't changed
            _rgAxisValues[axisIndex] = newAxisValue;
            emit rawAxisValueChanged(axisIndex, newAxisValue);
        }

        // Update buttons
        for (int buttonIndex=0; buttonIndex<_buttonCount; buttonIndex++) {
            bool newButtonValue = _getButton(buttonIndex);
            if (newButtonValue != _rgButtonValues[buttonIndex]) {
                _rgButtonValues[buttonIndex] = newButtonValue;
                emit rawButtonPressedChanged(buttonIndex, newButtonValue);
            }
        }

        // Update hat - append hat buttons to the end of the normal button list
        int numHatButtons = 4;
        for (int hatIndex=0; hatIndex<_hatCount; hatIndex++) {
            for (int hatButtonIndex=0; hatButtonIndex<numHatButtons; hatButtonIndex++) {
                // Create new index value that includes the normal button list
                int rgButtonValueIndex = hatIndex*numHatButtons + hatButtonIndex + _buttonCount;
                // Get hat value from joystick
                bool newButtonValue = _getHat(hatIndex,hatButtonIndex);
                if (newButtonValue != _rgButtonValues[rgButtonValueIndex]) {
                    _rgButtonValues[rgButtonValueIndex] = newButtonValue;
                    emit rawButtonPressedChanged(rgButtonValueIndex, newButtonValue);
                }
            }
        }

        if (_calibrationMode != CalibrationModeCalibrating) {
            Axis_t  axis = _rgFunctionAxis[rollFunction];
            int     mappedAxis = _rgAxisMapping[axis];
            float   roll = _adjustRange(_rgAxisValues[mappedAxis], _rgCalibration[mappedAxis], _deadband);

                    axis = _rgFunctionAxis[pitchFunction];
                    mappedAxis = _rgAxisMapping[axis];
            float   pitch = _adjustRange(_rgAxisValues[mappedAxis], _rgCalibration[mappedAxis], _deadband);

                    axis = _rgFunctionAxis[yawFunction];
                    mappedAxis = _rgAxisMapping[axis];
            float   yaw = _adjustRange(_rgAxisValues[mappedAxis], _rgCalibration[mappedAxis],_deadband);

                    axis = _rgFunctionAxis[throttleFunction];
                    mappedAxis = _rgAxisMapping[axis];
            float   throttle = _adjustRange(_rgAxisValues[mappedAxis], _rgCalibration[mappedAxis], _throttleMode==ThrottleModeDownZero?false:_deadband);

            if ( _accumulator ) {
                static float throttle_accu = 0.f;

                throttle_accu += throttle*(40/1000.f); //for throttle to change from min to max it will take 1000ms (40ms is a loop time)

                throttle_accu = std::max(static_cast<float>(-1.f), std::min(throttle_accu, static_cast<float>(1.f)));
                throttle = throttle_accu;
            }

            float roll_limited = std::max(static_cast<float>(-M_PI_4), std::min(roll, static_cast<float>(M_PI_4)));
            float pitch_limited = std::max(static_cast<float>(-M_PI_4), std::min(pitch, static_cast<float>(M_PI_4)));
            float yaw_limited = std::max(static_cast<float>(-M_PI_4), std::min(yaw, static_cast<float>(M_PI_4)));
            float throttle_limited = std::max(static_cast<float>(-M_PI_4), std::min(throttle, static_cast<float>(M_PI_4)));

            // Map from unit circle to linear range and limit
            roll =      std::max(-1.0f, std::min(tanf(asinf(roll_limited)), 1.0f));
            pitch =     std::max(-1.0f, std::min(tanf(asinf(pitch_limited)), 1.0f));
            yaw =       std::max(-1.0f, std::min(tanf(asinf(yaw_limited)), 1.0f));
            throttle =  std::max(-1.0f, std::min(tanf(asinf(throttle_limited)), 1.0f));
            
            if ( _exponential ) {
                // Exponential (0% to -50% range like most RC radios)
                // 0 for no exponential
                // -0.5 for strong exponential
                float expo = -0.35f;

                // Calculate new RPY with exponential applied
                roll =      -expo*powf(roll,3) + (1+expo)*roll;
                pitch =     -expo*powf(pitch,3) + (1+expo)*pitch;
                yaw =       -expo*powf(yaw,3) + (1+expo)*yaw;
            }

            // Adjust throttle to 0:1 range
            if (_throttleMode == ThrottleModeCenterZero && _activeVehicle->supportsThrottleModeCenterZero()) {
                throttle = std::max(0.0f, throttle);
            } else {
                throttle = (throttle + 1.0f) / 2.0f;
            }

            // Set up button pressed information

            // We only send the buttons the firmwware has reserved
            int reservedButtonCount = _activeVehicle->manualControlReservedButtonCount();
            if (reservedButtonCount == -1) {
                reservedButtonCount = _totalButtonCount;
            }

            quint16 newButtonBits = 0;      // New set of button which are down
            quint16 buttonPressedBits = 0;  // Buttons pressed for manualControl signal

            for (int buttonIndex=0; buttonIndex<_totalButtonCount; buttonIndex++) {
                quint16 buttonBit = 1 << buttonIndex;

                if (!_rgButtonValues[buttonIndex]) {
                    // Button up, just record it
                    newButtonBits |= buttonBit;
                } else {
                    if (_lastButtonBits & buttonBit) {
                        // Button was up last time through, but is now down which indicates a button press
                        qCDebug(JoystickLog) << "button triggered" << buttonIndex;

                        if (buttonIndex >= reservedButtonCount) {
                            // Button is above firmware reserved set
                            QString buttonAction =_rgButtonActions[buttonIndex];
                            if (!buttonAction.isEmpty()) {
                                _buttonAction(buttonAction);
                            }
                        }
                    }

                    // Mark the button as pressed as long as its pressed
                    buttonPressedBits |= buttonBit;
                }
            }

            _lastButtonBits = newButtonBits;

            qCDebug(JoystickValuesLog) << "name:roll:pitch:yaw:throttle" << name() << roll << -pitch << yaw << throttle;

            emit manualControl(roll, -pitch, yaw, throttle, buttonPressedBits, _activeVehicle->joystickMode());
        }

        // Sleep, update rate of joystick is approx. 25 Hz (1000 ms / 25 = 40 ms)
        QGC::SLEEP::msleep(40);
    }

    _close();
}

void Joystick::startPolling(Vehicle* vehicle)
{
    if (vehicle) {

        // If a vehicle is connected, disconnect it
        if (_activeVehicle) {
            UAS* uas = _activeVehicle->uas();
            disconnect(this, &Joystick::manualControl, uas, &UAS::setExternalControlSetpoint);
        }

        // Always set up the new vehicle
        _activeVehicle = vehicle;

        // If joystick is not calibrated, disable it
        if ( !_calibrated ) {
            vehicle->setJoystickEnabled(false);
        }

        // Only connect the new vehicle if it wants joystick data
        if (vehicle->joystickEnabled()) {
            _pollingStartedForCalibration = false;

            UAS* uas = _activeVehicle->uas();
            connect(this, &Joystick::manualControl, uas, &UAS::setExternalControlSetpoint);
            // FIXME: ****
            //connect(this, &Joystick::buttonActionTriggered, uas, &UAS::triggerAction);
        }
    }


    if (!isRunning()) {
        _exitThread = false;
        start();
    }
}

void Joystick::stopPolling(void)
{
    if (isRunning()) {

        if (_activeVehicle && _activeVehicle->joystickEnabled()) {
            UAS* uas = _activeVehicle->uas();

            disconnect(this, &Joystick::manualControl,          uas, &UAS::setExternalControlSetpoint);
        }
        // FIXME: ****
        //disconnect(this, &Joystick::buttonActionTriggered,  uas, &UAS::triggerAction);

        _exitThread = true;
        }
}

void Joystick::setCalibration(int axis, Calibration_t& calibration)
{
    if (!_validAxis(axis)) {
        qCWarning(JoystickLog) << "Invalid axis index" << axis;
        return;
    }

    _calibrated = true;
    _rgCalibration[axis] = calibration;
    _saveSettings();
    emit calibratedChanged(_calibrated);
}

void Joystick::setAxisMapping(Axis_t axis, int map)
{
    _rgAxisMapping[axis] = map;
    _saveSettings();
}

Joystick::Calibration_t Joystick::getCalibration(int axis)
{
    if (!_validAxis(axis)) {
        qCWarning(JoystickLog) << "Invalid axis index" << axis;
    }

    return _rgCalibration[axis];
}

void Joystick::setFunctionAxis(AxisFunction_t function, Axis_t axis)
{
    if (!_validAxis(axis)) {
        qCWarning(JoystickLog) << "Invalid axis index" << axis;
        return;
    }

    _calibrated = true;
    _rgFunctionAxis[function] = axis;
    _saveSettings();
    emit calibratedChanged(_calibrated);
}

Joystick::Axis_t Joystick::getFunctionAxis(AxisFunction_t function)
{
    if (function < 0 || function >= maxFunction) {
        qCWarning(JoystickLog) << "Invalid function" << function;
    }

    return _rgFunctionAxis[function];
}

QStringList Joystick::actions(void)
{
    QStringList list;

    list << "Arm" << "Disarm";

    if (_activeVehicle) {
        list << _activeVehicle->flightModes();
    }

    return list;
}

void Joystick::setButtonAction(int button, const QString& action)
{
    if (!_validButton(button)) {
        qCWarning(JoystickLog) << "Invalid button index" << button;
        return;
    }

    qDebug() << "setButtonAction" << action;

    _rgButtonActions[button] = action;
    _saveSettings();
    emit buttonActionsChanged(buttonActions());
}

QString Joystick::getButtonAction(int button)
{
    if (!_validButton(button)) {
        qCWarning(JoystickLog) << "Invalid button index" << button;
    }

    return _rgButtonActions[button];
}

QVariantList Joystick::buttonActions(void)
{
    QVariantList list;

    for (int button=0; button<_totalButtonCount; button++) {
        list += QVariant::fromValue(_rgButtonActions[button]);
    }

    return list;
}

void Joystick::setMode(int mode, bool save)
{
    Joystick::_mode = mode;
    qCDebug(JoystickLog) << "New Mode:" << Joystick::_mode;

    switch(Joystick::_mode) {
    case 1:
        _rgFunctionAxis[rollFunction] = stickRightX;
        _rgFunctionAxis[pitchFunction] = stickLeftY;
        _rgFunctionAxis[yawFunction] = stickLeftX;
        _rgFunctionAxis[throttleFunction] = stickRightY;
        break;
    case 2:
        _rgFunctionAxis[rollFunction] = stickRightX;
        _rgFunctionAxis[pitchFunction] = stickRightY;
        _rgFunctionAxis[yawFunction] = stickLeftX;
        _rgFunctionAxis[throttleFunction] = stickLeftY;
        break;
    case 3:
        _rgFunctionAxis[rollFunction] = stickLeftX;
        _rgFunctionAxis[pitchFunction] = stickLeftY;
        _rgFunctionAxis[yawFunction] = stickRightX;
        _rgFunctionAxis[throttleFunction] = stickRightY;
        break;
    case 4:
        _rgFunctionAxis[rollFunction] = stickLeftX;
        _rgFunctionAxis[pitchFunction] = stickRightY;
        _rgFunctionAxis[yawFunction] = stickRightX;
        _rgFunctionAxis[throttleFunction] = stickLeftY;
        break;
    default:
        qCDebug(JoystickLog) << "Invalid Mode:" << Joystick::_mode;
    }

    if(save) {
        _saveSettings();
    }

    emit modeChanged(Joystick::_mode);
}

int Joystick::throttleMode(void)
{
    return _throttleMode;
}

void Joystick::setThrottleMode(int mode)
{
    if (mode < 0 || mode >= ThrottleModeMax) {
        qCWarning(JoystickLog) << "Invalid throttle mode" << mode;
        return;
    }

    _throttleMode = (ThrottleMode_t)mode;

    if (_throttleMode == ThrottleModeDownZero) {
        setAccumulator(false);
    }

    _saveSettings();
    emit throttleModeChanged(_throttleMode);
}

bool Joystick::exponential(void)
{
    return _exponential;
}

void Joystick::setExponential(bool expo)
{
    _exponential = expo;

    _saveSettings();
    emit exponentialChanged(_exponential);
}

bool Joystick::accumulator(void)
{
    return _accumulator;
}

void Joystick::setAccumulator(bool accu)
{
    _accumulator = accu;

    _saveSettings();
    emit accumulatorChanged(_accumulator);
}

bool Joystick::deadband(void)
{
    return _deadband;
}

void Joystick::setDeadband(bool deadband)
{
    _deadband = deadband;

    _saveSettings();
}

void Joystick::startCalibrationMode(CalibrationMode_t mode)
{
    if (mode == CalibrationModeOff) {
        qWarning() << "Incorrect mode CalibrationModeOff";
        return;
    }

    _calibrationMode = mode;

    if (!isRunning()) {
        _pollingStartedForCalibration = true;
        startPolling(_multiVehicleManager->activeVehicle());
    }
}

void Joystick::stopCalibrationMode(CalibrationMode_t mode)
{
    if (mode == CalibrationModeOff) {
        qWarning() << "Incorrect mode: CalibrationModeOff";
        return;
    }

    if (mode == CalibrationModeCalibrating) {
        _calibrationMode = CalibrationModeMonitor;
    } else {
        _calibrationMode = CalibrationModeOff;
        if (_pollingStartedForCalibration) {
            stopPolling();
        }
    }
}

void Joystick::_buttonAction(const QString& action)
{
    if (!_activeVehicle || !_activeVehicle->joystickEnabled()) {
        return;
    }

    if (action == "Arm") {
        _activeVehicle->setArmed(true);
    } else if (action == "Disarm") {
        _activeVehicle->setArmed(false);
    } else if (_activeVehicle->flightModes().contains(action)) {
        _activeVehicle->setFlightMode(action);
    } else {
        qCDebug(JoystickLog) << "_buttonAction unknown action:" << action;
    }
}

bool Joystick::_validAxis(int axis)
{
    return axis >= 0 && axis < _axisCount;
}

bool Joystick::_validButton(int button)
{
    return button >= 0 && button < _totalButtonCount;
}

