/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.5
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.2
import QtQuick.Dialogs         1.2

import QGroundControl.ScreenTools   1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Palette 1.0
import QGroundControl.Controls 1.0

Item {
    id: stepper
    property bool enabled: true
    property alias fact: factInput.fact
    property alias showHelp: factInput.showHelp
    property alias showUnits: factInput.showUnits

    property double _factValue: Number(factInput.text)

    property double minimumValue: !fact || isNaN(fact.min) ? 0 : fact.min
    property double maximumValue: !fact || isNaN(fact.max) ? 10000 : fact.max
    property double increment: !fact || isNaN(fact.increment) ? 0.001 : fact.increment
    property double incrementRatio: 1.0

    implicitHeight: 50
    implicitWidth: implicitHeight * 4

    signal validationError(string text, string errorText)
    signal valueChanged(string text)
    signal helpClicked

    Component.onCompleted: {
        factInput.validationError.connect(validationError)
        factInput.valueChanged.connect(valueChanged)
        factInput.helpClicked.connect(helpClicked)
   }

    function incrementWithScale(multiplier) {
        var newValue = _factValue + (increment * incrementRatio * multiplier)
        newValue = Math.max(newValue, minimumValue)
        newValue = Math.min(newValue, maximumValue)

        factInput.setFactValue(newValue)
    }

    Timer {
        id: factValueChangeDelay

        interval: 250
        repeat: false
        running: false

        onTriggered: {
            factInput.setFactValueImpl(factInput.text)
        }
    }

    Row {
        anchors.fill:   parent

        QGCButton {
            id: minusButton
            width : parent.width / 4
            height: parent.height
            text: "-"
            enabled: _factValue > minimumValue

            onClicked: {
                incrementWithScale(-1)
            }
        }

        FactBaseTextField {
            id: factInput
            width : parent.width / 2
            height: parent.height

            horizontalAlignment: TextInput.AlignHCenter

            function setFactValue(newValue) {
                factValueChangeDelay.stop()

                text = newValue.toLocaleString(Qt.locale(), 'f', fact.decimalPlaces)
                factValueChangeDelay.start()
            }

            onValidationError: textColor = qgcPal.warningText
            onValueChanged: textColor = qgcPal.textFieldText
        }

        QGCButton {
            id: plusButton
            width : parent.width / 4
            height: parent.height
            text: "+"
            enabled: _factValue < maximumValue

            onClicked: {
                incrementWithScale(1);
            }
        }
    }
}
