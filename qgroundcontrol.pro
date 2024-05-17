################################################################################
#
# (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
#
# QGroundControl is licensed according to the terms in the file
# COPYING.md in the root of the source code directory.
#
################################################################################

QMAKE_PROJECT_DEPTH = 0 # undocumented qmake flag to force absolute paths in makefiles

# DEFINES += QGC_AIRLINK_DISABLED

message ("ANDROID_TARGET_ARCH $${ANDROID_TARGET_ARCH} $${QT_ARCH}")

exists($${OUT_PWD}/qgroundcontrol.pro) {
    error("You must use shadow build (e.g. mkdir build; cd build; qmake ../qgroundcontrol.pro).")
}

message(Qt version $$[QT_VERSION])

!contains(CONFIG, DISABLE_QT_VERSION_CHECK) {
    !equals(QT_MAJOR_VERSION, 6) | !equals(QT_MINOR_VERSION, 6) {
        error("Unsupported Qt version, 6.6 is required. Found $$QT_MAJOR_VERSION.$$QT_MINOR_VERSION")
    }
}

include(QGCCommon.pri)

TARGET   = QGroundControl
TEMPLATE = app
QGCROOT  = $$PWD

QML_IMPORT_PATH += $$PWD/src/QmlControls

#
# OS Specific settings
#

MacBuild {
    QMAKE_INFO_PLIST    = deploy/mac/QGC-qmake-info.plist
    ICON                = $${SOURCE_DIR}/resources/icons/macx.icns
    OTHER_FILES        += deploy/mac/QGC-qmake-info.plist
    LIBS               += -framework ApplicationServices
}

LinuxBuild {
    CONFIG += qesp_linux_udev
    system("$$QMAKE_LINK -fuse-ld=gold -Wl,--version &>/dev/null") {
        CONFIG += use_gold_linker
    }
}

WindowsBuild {
    RC_ICONS = resources/icons/qgroundcontrol.ico
    CONFIG += resources_big
}

#
# Branding
#

QGC_APP_NAME        = "QGroundControl"
QGC_ORG_NAME        = "QGroundControl.org"
QGC_ORG_DOMAIN      = "org.qgroundcontrol"
QGC_APP_DESCRIPTION = "Open source ground control app provided by QGroundControl dev team"
QGC_APP_COPYRIGHT   = "Copyright (C) 2019 QGroundControl Development Team. All rights reserved."

WindowsBuild {
    QGC_INSTALLER_SCRIPT        = "$$SOURCE_DIR\\deploy\\windows\\nullsoft_installer.nsi"
    QGC_INSTALLER_ICON          = "$$SOURCE_DIR\\deploy\\windows\\WindowsQGC.ico"
    QGC_INSTALLER_HEADER_BITMAP = "$$SOURCE_DIR\\deploy\\windows\\installheader.bmp"
    QGC_INSTALLER_DRIVER_MSI    = "$$SOURCE_DIR\\deploy\\windows\\driver.msi"
}

# Load additional config flags from user_config.pri
exists(user_config.pri):infile(user_config.pri, CONFIG) {
    CONFIG += $$fromfile(user_config.pri, CONFIG)
    message($$sprintf("Using user-supplied additional config: '%1' specified in user_config.pri", $$fromfile(user_config.pri, CONFIG)))
}

#
# Custom Build
#
# QGC will create a "CUSTOMCLASS" object (exposed by your custom build
# and derived from QGCCorePlugin).
# This is the start of allowing custom Plugins, which will eventually use a
# more defined runtime plugin architecture and not require a QGC project
# file you would have to keep in sync with the upstream repo.
#

# This allows you to ignore the custom build even if the custom build
# is present. It's useful to run "regular" builds to make sure you didn't
# break anything.

contains (CONFIG, QGC_DISABLE_CUSTOM_BUILD) {
    message("Disable custom build override")
} else {
    exists($$PWD/custom/custom.pri) {
        message("Found custom build")
        CONFIG  += CustomBuild
        DEFINES += QGC_CUSTOM_BUILD
        # custom.pri must define:
        # CUSTOMCLASS  = YourIQGCCorePluginDerivation
        # CUSTOMHEADER = \"\\\"YourIQGCCorePluginDerivation.h\\\"\"
        include($$PWD/custom/custom.pri)
    }
}

WindowsBuild {
    # Sets up application properties
    QMAKE_TARGET_COMPANY        = "$${QGC_ORG_NAME}"
    QMAKE_TARGET_DESCRIPTION    = "$${QGC_APP_DESCRIPTION}"
    QMAKE_TARGET_COPYRIGHT      = "$${QGC_APP_COPYRIGHT}"
    QMAKE_TARGET_PRODUCT        = "$${QGC_APP_NAME}"
}

#-------------------------------------------------------------------------------------
# iOS

iOSBuild {
    contains (CONFIG, DISABLE_BUILTIN_IOS) {
        message("Skipping builtin support for iOS")
    } else {
        LIBS                 += -framework AVFoundation
        #-- Info.plist (need an "official" one for the App Store)
        ForAppStore {
            message(App Store Build)
            #-- Create official, versioned Info.plist
            APP_STORE = $$system(cd $${SOURCE_DIR} && $${SOURCE_DIR}/tools/update_ios_version.sh $${SOURCE_DIR}/deploy/ios/iOSForAppStore-Info-Source.plist $${SOURCE_DIR}/ios/deploy/iOSForAppStore-Info.plist)
            APP_ERROR = $$find(APP_STORE, "Error")
            count(APP_ERROR, 1) {
                error("Error building .plist file. 'ForAppStore' builds are only possible through the official build system.")
            }
            QT               += qml-private
            QMAKE_INFO_PLIST  = $${SOURCE_DIR}/ios/deploy/iOSForAppStore-Info.plist
            OTHER_FILES      += $${SOURCE_DIR}/ios/deploy/iOSForAppStore-Info.plist
        } else {
            QMAKE_INFO_PLIST  = $${SOURCE_DIR}/ios/deploy/iOS-Info.plist
            OTHER_FILES      += $${SOURCE_DIR}/ios/deploy/iOS-Info.plist
        }
        QMAKE_ASSET_CATALOGS += ios/deploy/Images.xcassets
        BUNDLE.files          = ios/deploy/QGCLaunchScreen.xib $$QMAKE_INFO_PLIST
        QMAKE_BUNDLE_DATA    += BUNDLE
    }
}

#
# Plugin configuration
#
# This allows you to build custom versions of QGC which only includes your
# specific vehicle plugin. To remove support for a firmware type completely,
# disable both the Plugin and PluginFactory entries. To include custom support
# for an existing plugin type disable PluginFactory only. Then provide you own
# implementation of FirmwarePluginFactory and use the FirmwarePlugin and
# AutoPilotPlugin classes as the base clase for your derived plugin
# implementation.

contains (CONFIG, QGC_DISABLE_APM_PLUGIN) {
    message("Disable APM Plugin")
} else {
    CONFIG += APMFirmwarePlugin
}

contains (CONFIG, QGC_DISABLE_APM_PLUGIN_FACTORY) {
    message("Disable APM Plugin Factory")
} else {
    CONFIG += APMFirmwarePluginFactory
}

contains (CONFIG, QGC_DISABLE_PX4_PLUGIN) {
    message("Disable PX4 Plugin")
} else {
    CONFIG += PX4FirmwarePlugin
}

contains (CONFIG, QGC_DISABLE_PX4_PLUGIN_FACTORY) {
    message("Disable PX4 Plugin Factory")
} else {
    CONFIG += PX4FirmwarePluginFactory
}

# Bluetooth
contains (DEFINES, QGC_DISABLE_BLUETOOTH) {
    message("Bluetooth support disabled (manual override from command line)")
    DEFINES -= QGC_ENABLE_BLUETOOTH
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, QGC_DISABLE_BLUETOOTH) {
    message("Bluetooth support disabled (manual override from user_config.pri)")
    DEFINES -= QGC_ENABLE_BLUETOOTH
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, QGC_ENABLE_BLUETOOTH) {
    DEFINES += QGC_ENABLE_BLUETOOTH
}

# QTNFC
contains (DEFINES, QGC_DISABLE_QTNFC) {
    message("Skipping support for QTNFC (manual override from command line)")
    DEFINES -= QGC_ENABLE_QTNFC
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, QGC_DISABLE_QTNFC) {
    message("Skipping support for QTNFC (manual override from user_config.pri)")
    DEFINES -= QGC_ENABLE_QTNFC
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, QGC_ENABLE_QTNFC) {
    message("Including support for QTNFC (manual override from user_config.pri)")
    DEFINES += QGC_ENABLE_QTNFC
}

# USB Camera and UVC Video Sources
contains (DEFINES, QGC_DISABLE_UVC) {
    message("Skipping support for UVC devices (manual override from command line)")
    DEFINES += QGC_DISABLE_UVC
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, QGC_DISABLE_UVC) {
    message("Skipping support for UVC devices (manual override from user_config.pri)")
    DEFINES += QGC_DISABLE_UVC
} else:LinuxBuild {
    contains(QT_VERSION, 5.5.1) {
        message("Skipping support for UVC devices (conflict with Qt 5.5.1 on Ubuntu)")
        DEFINES += QGC_DISABLE_UVC
    }
}

LinuxBuild {
    CONFIG += link_pkgconfig
}

# Qt configuration

CONFIG += qt \
    thread

DebugBuild {
    CONFIG -= qtquickcompiler
} else {
    CONFIG += qtquickcompiler
}

contains(DEFINES, ENABLE_VERBOSE_OUTPUT) {
    message("Enable verbose compiler output (manual override from command line)")
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, ENABLE_VERBOSE_OUTPUT) {
    message("Enable verbose compiler output (manual override from user_config.pri)")
} else {
    CONFIG += silent
}

QT += \
    concurrent \
    gui \
    location \
    network \
    opengl \
    positioning \
    qml \
    quick \
    quickcontrols2 \
    quickwidgets \
    sql \
    svg \
    widgets \
    xml \
    texttospeech \
    core-private \
    core5compat \
    quick3d \
    sensors

# Multimedia only used if QVC is enabled
!contains (DEFINES, QGC_DISABLE_UVC) {
    QT += \
        multimedia
}

!iOSBuild {
    QT += \
        serialport \
}

contains(DEFINES, QGC_ENABLE_BLUETOOTH) {
QT += \
    bluetooth \
}

contains(DEFINES, QGC_ENABLE_QTNFC) {
QT += \
    nfc \
}

#
# Build-specific settings
#

DebugBuild {
!iOSBuild {
    CONFIG += console
}
}

#
# Our QtLocation "plugin"
#

include(src/QtLocationPlugin/QGCLocationPlugin.pri)

#
# External library configuration
#

include(QGCExternalLibs.pri)

#
# Resources (custom code can replace them)
#

CustomBuild {
    exists($$PWD/custom/qgroundcontrol.qrc) {
        message("Using custom qgroundcontrol.qrc")
        RESOURCES += $$PWD/custom/qgroundcontrol.qrc
    } else {
        RESOURCES += $$PWD/qgroundcontrol.qrc
    }
    exists($$PWD/custom/qgcresources.qrc) {
        message("Using custom qgcresources.qrc")
        RESOURCES += $$PWD/custom/qgcresources.qrc
    } else {
        RESOURCES += $$PWD/qgcresources.qrc
    }
    exists($$PWD/custom/qgcimages.qrc) {
        message("Using custom qgcimages.qrc")
        RESOURCES += $$PWD/custom/qgcimages.qrc
    } else {
        RESOURCES += $$PWD/qgcimages.qrc
    }
    exists($$PWD/custom/InstrumentValueIcons.qrc) {
        message("Using custom InstrumentValueIcons.qrc")
        RESOURCES += $$PWD/custom/InstrumentValueIcons.qrc
    } else {
        RESOURCES += $$PWD/resources/InstrumentValueIcons/InstrumentValueIcons.qrc
    }
} else {
    DEFINES += QGC_APP_NAME=\"\\\"QGroundControl\\\"\"
    DEFINES += QGC_ORG_NAME=\"\\\"QGroundControl.org\\\"\"
    DEFINES += QGC_ORG_DOMAIN=\"\\\"org.qgroundcontrol\\\"\"
    RESOURCES += \
        $$PWD/qgroundcontrol.qrc \
        $$PWD/qgcresources.qrc \
        $$PWD/qgcimages.qrc \
        $$PWD/resources/InstrumentValueIcons/InstrumentValueIcons.qrc \
}

#
# Main QGroundControl portion of project file
#

DEPENDPATH += \
    . \
    plugins

INCLUDEPATH += .

INCLUDEPATH += \
    include/ui \
    src \
    src/ADSB \
    src/API \
    src/AnalyzeView \
    src/Camera \
    src/AutoPilotPlugins \
    src/FlightDisplay \
    src/FlightMap \
    src/FlightMap/Widgets \
    src/FollowMe \
    src/Geo \
    src/GPS \
    src/Joystick \
    src/MAVLink \
    src/MAVLink/LibEvents \
    src/PlanView \
    src/MissionManager \
    src/PositionManager \
    src/QmlControls \
    src/QtLocationPlugin \
    src/QtLocationPlugin/QMLControl \
    src/Settings \
    src/Terrain \
    src/Vehicle \
    src/Vehicle/Actuators \
    src/Vehicle/Components \
    src/Vehicle/FactGroups \
    src/Vehicle/LibEvents \
    src/Audio \
    src/Comms \
    src/Comms/MockLink \
    src/input \
    src/lib/qmapcontrol \
    src/uas \
    src/ui \
    src/ui/linechart \
    src/ui/map \
    src/ui/mapdisplay \
    src/ui/mission \
    src/ui/px4_configuration \
    src/ui/toolbar \
    src/ui/uas \
    src/Viewer3D \
    src/Utilities \
    src/Utilities/Compression

#
# Plugin API
#

HEADERS += \
    src/QmlControls/CustomAction.h \
    src/QmlControls/CustomActionManager.h \
    src/QmlControls/QmlUnitsConversion.h \
    src/Vehicle/FactGroups/VehicleEscStatusFactGroup.h \
    src/API/QGCCorePlugin.h \
    src/API/QGCOptions.h \
    src/API/QGCSettings.h \
    src/API/QmlComponentInfo.h \
    src/GPS/Drivers/src/base_station.h \

SOURCES += \
    src/QmlControls/CustomAction.cc \
    src/QmlControls/CustomActionManager.cc \
    src/Vehicle/FactGroups/VehicleEscStatusFactGroup.cc \
    src/API/QGCCorePlugin.cc \
    src/API/QGCOptions.cc \
    src/API/QGCSettings.cc \
    src/API/QmlComponentInfo.cc \

# Main QGC Headers and Source files

HEADERS += \
    src/ADSB/ADSBTCPLink.h \
    src/ADSB/ADSBVehicle.h \
    src/ADSB/ADSBVehicleManager.h \
    src/AnalyzeView/LogDownloadController.h \
    src/AnalyzeView/LogEntry.h \
    src/AnalyzeView/PX4LogParser.h \
    src/AnalyzeView/ULogParser.h \
    src/AnalyzeView/MAVLinkConsoleController.h \
    src/AnalyzeView/MAVLinkMessage.h \
    src/AnalyzeView/MAVLinkMessageField.h \
    src/AnalyzeView/MAVLinkSystem.h \
    src/Audio/AudioOutput.h \
    src/Vehicle/Autotune.h \
    src/Camera/MavlinkCameraControl.h \
    src/Camera/SimulatedCameraControl.h \
    src/Camera/VehicleCameraControl.h \
    src/Camera/QGCCameraIO.h \
    src/Camera/QGCCameraManager.h \
    src/CmdLineOptParser.h \
    src/Utilities/Compression/QGCLZMA.h \
    src/Utilities/Compression/QGCZlib.h \
    src/FirmwarePlugin/PX4/px4_custom_mode.h \
    src/FollowMe/FollowMe.h \
    src/Joystick/Joystick.h \
    src/Joystick/JoystickManager.h \
    src/Utilities/JsonHelper.h \
    src/Utilities/KMLDomDocument.h \
    src/Utilities/KMLHelper.h \
    src/MissionManager/CameraCalc.h \
    src/MissionManager/CameraSection.h \
    src/MissionManager/CameraSpec.h \
    src/MissionManager/ComplexMissionItem.h \
    src/MissionManager/CorridorScanComplexItem.h \
    src/MissionManager/CorridorScanPlanCreator.h \
    src/MissionManager/BlankPlanCreator.h \
    src/MissionManager/FixedWingLandingComplexItem.h \
    src/MissionManager/GeoFenceController.h \
    src/MissionManager/GeoFenceManager.h \
    src/MissionManager/KMLPlanDomDocument.h \
    src/MissionManager/LandingComplexItem.h \
    src/MissionManager/MissionCommandList.h \
    src/MissionManager/MissionCommandTree.h \
    src/MissionManager/MissionCommandUIInfo.h \
    src/MissionManager/MissionController.h \
    src/MissionManager/MissionItem.h \
    src/MissionManager/MissionManager.h \
    src/MissionManager/MissionSettingsItem.h \
    src/MissionManager/PlanElementController.h \
    src/MissionManager/PlanCreator.h \
    src/MissionManager/PlanManager.h \
    src/MissionManager/PlanMasterController.h \
    src/QmlControls/QGCFenceCircle.h \
    src/QmlControls/QGCFencePolygon.h \
    src/QmlControls/QGCMapCircle.h \
    src/QmlControls/QGCMapPolygon.h \
    src/QmlControls/QGCMapPolyline.h \
    src/MissionManager/RallyPoint.h \
    src/MissionManager/RallyPointController.h \
    src/MissionManager/RallyPointManager.h \
    src/MissionManager/SimpleMissionItem.h \
    src/MissionManager/Section.h \
    src/MissionManager/SpeedSection.h \
    src/MissionManager/StructureScanComplexItem.h \
    src/MissionManager/StructureScanPlanCreator.h \
    src/MissionManager/SurveyComplexItem.h \
    src/MissionManager/SurveyPlanCreator.h \
    src/MissionManager/TakeoffMissionItem.h \
    src/MissionManager/TransectStyleComplexItem.h \
    src/MissionManager/VisualMissionItem.h \
    src/MissionManager/VTOLLandingComplexItem.h \
    src/PositionManager/PositionManager.h \
    src/PositionManager/SimulatedPosition.h \
    src/Geo/QGCGeo.h \
    src/Utilities/QGC.h \
    src/Utilities/DeviceInfo.h \
    src/QGCApplication.h \
    src/Utilities/QGCCachedFileDownload.h \
    src/QGCConfig.h \
    src/Utilities/QGCFileDownload.h \
    src/Utilities/QGCLoggingCategory.h \
    src/QmlControls/QGCMapPalette.h \
    src/QmlControls/QGCPalette.h \
    src/QmlControls/QGCQGeoCoordinate.h \
    src/Utilities/QGCTemporaryFile.h \
    src/QGCToolbox.h \
    src/QmlControls/AppMessages.h \
    src/QmlControls/EditPositionDialogController.h \
    src/QmlControls/FlightPathSegment.h \
    src/QmlControls/HorizontalFactValueGrid.h \
    src/QmlControls/InstrumentValueData.h \
    src/QmlControls/FactValueGrid.h \
    src/QmlControls/ParameterEditorController.h \
    src/QmlControls/QGCFileDialogController.h \
    src/QmlControls/QGCImageProvider.h \
    src/QmlControls/QGroundControlQmlGlobal.h \
    src/QmlControls/QmlObjectListModel.h \
    src/QmlControls/QGCGeoBoundingCube.h \
    src/QmlControls/RCChannelMonitorController.h \
    src/QmlControls/RCToParamDialogController.h \
    src/QmlControls/ScreenToolsController.h \
    src/QmlControls/TerrainProfile.h \
    src/QmlControls/ToolStripAction.h \
    src/QmlControls/ToolStripActionList.h \
    src/QtLocationPlugin/QMLControl/QGCMapEngineManager.h \
    src/Settings/ADSBVehicleManagerSettings.h \
    src/Settings/AppSettings.h \
    src/Settings/AutoConnectSettings.h \
    src/Settings/BatteryIndicatorSettings.h \
    src/Settings/BrandImageSettings.h \
    src/Settings/CustomMavlinkActionsSettings.h \
    src/Settings/RemoteIDSettings.h \
    src/Settings/FirmwareUpgradeSettings.h \
    src/Settings/FlightMapSettings.h \
    src/Settings/FlightModeSettings.h \
    src/Settings/FlyViewSettings.h \
    src/Settings/MapsSettings.h \
    src/Settings/OfflineMapsSettings.h \
    src/Settings/PlanViewSettings.h \
    src/Settings/RTKSettings.h \
    src/Settings/SettingsGroup.h \
    src/Settings/SettingsManager.h \
    src/Settings/UnitsSettings.h \
    src/Settings/VideoSettings.h \
    src/Utilities/ShapeFileHelper.h \
    src/Utilities/SHPFileHelper.h \
    src/Terrain/TerrainQuery.h \
    src/Terrain/TerrainQueryAirMap.h \
    src/Terrain/TerrainTile.h \
    src/Terrain/TerrainTileManager.h \
    src/Vehicle/Actuators/ActuatorActions.h \
    src/Vehicle/Actuators/Actuators.h \
    src/Vehicle/Actuators/ActuatorOutputs.h \
    src/Vehicle/Actuators/ActuatorTesting.h \
    src/Vehicle/Actuators/Common.h \
    src/Vehicle/Actuators/GeometryImage.h \
    src/Vehicle/Actuators/Mixer.h \
    src/Vehicle/Actuators/MotorAssignment.h \
    src/MAVLink/LibEvents/EventHandler.h \
    src/MAVLink/LibEvents/HealthAndArmingCheckReport.h \
    src/MAVLink/LibEvents/libevents_includes.h \
    src/Vehicle/Components/CompInfo.h \
    src/Vehicle/Components/CompInfoActuators.h \
    src/Vehicle/Components/CompInfoEvents.h \
    src/Vehicle/Components/CompInfoParam.h \
    src/Vehicle/Components/CompInfoGeneral.h \
    src/Vehicle/Components/ComponentInformationCache.h \
    src/Vehicle/Components/ComponentInformationManager.h \
    src/Vehicle/Components/ComponentInformationTranslation.h \
    src/Vehicle/FTPManager.h \
    src/Vehicle/FactGroups/GPSRTKFactGroup.h \
    src/MAVLink/ImageProtocolManager.h \
    src/Vehicle/InitialConnectStateMachine.h \
    src/Vehicle/MAVLinkLogManager.h \
    src/MAVLink/MAVLinkStreamConfig.h \
    src/Vehicle/MultiVehicleManager.h \
    src/Vehicle/RemoteIDManager.h \
    src/Utilities/StateMachine.h \
    src/Vehicle/StandardModes.h \
    src/MAVLink/SysStatusSensorInfo.h \
    src/Vehicle/FactGroups/TerrainFactGroup.h \
    src/Vehicle/TerrainProtocolHandler.h \
    src/Vehicle/TrajectoryPoints.h \
    src/Vehicle/Vehicle.h \
    src/Vehicle/VehicleObjectAvoidance.h \
    src/Vehicle/FactGroups/VehicleBatteryFactGroup.h \
    src/Vehicle/FactGroups/VehicleClockFactGroup.h \
    src/Vehicle/FactGroups/VehicleDistanceSensorFactGroup.h \
    src/Vehicle/FactGroups/VehicleEstimatorStatusFactGroup.h \
    src/Vehicle/FactGroups/VehicleLocalPositionFactGroup.h \
    src/Vehicle/FactGroups/VehicleLocalPositionSetpointFactGroup.h \
    src/Vehicle/FactGroups/VehicleGPSFactGroup.h \
    src/Vehicle/FactGroups/VehicleGPS2FactGroup.h \
    src/Vehicle/VehicleLinkManager.h \
    src/Vehicle/FactGroups/VehicleSetpointFactGroup.h \
    src/Vehicle/FactGroups/VehicleTemperatureFactGroup.h \
    src/Vehicle/FactGroups/VehicleVibrationFactGroup.h \
    src/Vehicle/FactGroups/VehicleWindFactGroup.h \
    src/Vehicle/FactGroups/VehicleHygrometerFactGroup.h \
    src/Vehicle/FactGroups/VehicleGeneratorFactGroup.h \
    src/Vehicle/FactGroups/VehicleEFIFactGroup.h \
    src/VehicleSetup/JoystickConfigController.h \
    src/Comms/LinkConfiguration.h \
    src/Comms/LinkInterface.h \
    src/Comms/LinkManager.h \
    src/Comms/LogReplayLink.h \
    src/Comms/MAVLinkProtocol.h \
    src/MAVLink/QGCMAVLink.h \
    src/MAVLink/MAVLinkLib.h \
    src/MAVLink/MAVLinkFTP.h \
    src/MAVLink/StatusTextHandler.h \
    src/Comms/TCPLink.h \
    src/Comms/UDPLink.h \
    src/Comms/UdpIODevice.h \
    src/AnalyzeView/GeoTagController.h \
    src/AnalyzeView/GeoTagWorker.h \
    src/AnalyzeView/ExifParser.h \
    src/Viewer3D/CityMapGeometry.h \
    src/Viewer3D/OsmParser.h \
    src/Viewer3D/Viewer3DQmlBackend.h \
    src/Viewer3D/Viewer3DQmlVariableTypes.h \
    src/Viewer3D/Viewer3DUtils.h \
    src/Viewer3D/Viewer3DManager.h \
    src/Settings/Viewer3DSettings.h \
    src/Viewer3D/Viewer3DTileReply.h \
    src/Viewer3D/Viewer3DTerrainGeometry.h \
    src/Viewer3D/Viewer3DTerrainTexture.h \
    src/Viewer3D/Viewer3DTileQuery.h \
    src/Viewer3D/OsmParserThread.h \

AndroidBuild {
    HEADERS += \
        src/Joystick/JoystickAndroid.h \
}

DebugBuild {
HEADERS += \
    src/Comms/MockLink/MockLink.h \
    src/Comms/MockLink/MockLinkFTP.h \
    src/Comms/MockLink/MockLinkMissionItemHandler.h \
}

WindowsBuild {
    PRECOMPILED_HEADER += src/pch.h
    HEADERS += src/pch.h
    CONFIG -= silent
    OTHER_FILES += .appveyor.yml
}

contains(DEFINES, QGC_ENABLE_BLUETOOTH) {
    HEADERS += \
    src/Comms/BluetoothLink.h \
}

!contains(DEFINES, NO_SERIAL_LINK) {
HEADERS += \
    src/Comms/QGCSerialPortInfo.h \
    src/Comms/SerialLink.h \
}

!iosBuild {
HEADERS += \
    src/GPS/Drivers/src/gps_helper.h \
    src/GPS/Drivers/src/rtcm.h \
    src/GPS/Drivers/src/ashtech.h \
    src/GPS/Drivers/src/ubx.h \
    src/GPS/Drivers/src/sbf.h \
    src/GPS/GPSManager.h \
    src/GPS/GPSPositionMessage.h \
    src/GPS/GPSProvider.h \
    src/GPS/RTCMMavlink.h \
    src/GPS/definitions.h \
    src/GPS/satellite_info.h \
    src/GPS/sensor_gps.h \
    src/GPS/sensor_gnss_relative.h
}

!MobileBuild {
HEADERS += \
    src/Joystick/JoystickSDL.h \
    src/RunGuard.h
}

iOSBuild {
    OBJECTIVE_SOURCES += \
        src/Utilities/MobileScreenMgr.mm \
}

AndroidBuild {
    SOURCES += \
        src/Utilities/MobileScreenMgr.cc \
        src/Joystick/JoystickAndroid.cc

    HEADERS += src/Utilities/MobileScreenMgr.h
}

SOURCES += \
    src/ADSB/ADSBTCPLink.cc \
    src/ADSB/ADSBVehicle.cc \
    src/ADSB/ADSBVehicleManager.cc \
    src/AnalyzeView/LogDownloadController.cc \
    src/AnalyzeView/LogEntry.cc \
    src/AnalyzeView/PX4LogParser.cc \
    src/AnalyzeView/ULogParser.cc \
    src/AnalyzeView/MAVLinkConsoleController.cc \
    src/AnalyzeView/MAVLinkMessage.cc \
    src/AnalyzeView/MAVLinkMessageField.cc \
    src/AnalyzeView/MAVLinkSystem.cc \
    src/Audio/AudioOutput.cc \
    src/Vehicle/Autotune.cpp \
    src/Camera/MavlinkCameraControl.cc \
    src/Camera/SimulatedCameraControl.cc \
    src/Camera/VehicleCameraControl.cc \
    src/Camera/QGCCameraIO.cc \
    src/Camera/QGCCameraManager.cc \
    src/CmdLineOptParser.cc \
    src/Utilities/Compression/QGCLZMA.cc \
    src/Utilities/Compression/QGCZlib.cc \
    src/FollowMe/FollowMe.cc \
    src/Joystick/Joystick.cc \
    src/Joystick/JoystickManager.cc \
    src/Utilities/JsonHelper.cc \
    src/Utilities/KMLDomDocument.cc \
    src/Utilities/KMLHelper.cc \
    src/MissionManager/CameraCalc.cc \
    src/MissionManager/CameraSection.cc \
    src/MissionManager/CameraSpec.cc \
    src/MissionManager/ComplexMissionItem.cc \
    src/MissionManager/CorridorScanComplexItem.cc \
    src/MissionManager/CorridorScanPlanCreator.cc \
    src/MissionManager/BlankPlanCreator.cc \
    src/MissionManager/FixedWingLandingComplexItem.cc \
    src/MissionManager/GeoFenceController.cc \
    src/MissionManager/GeoFenceManager.cc \
    src/MissionManager/KMLPlanDomDocument.cc \
    src/MissionManager/LandingComplexItem.cc \
    src/MissionManager/MissionCommandList.cc \
    src/MissionManager/MissionCommandTree.cc \
    src/MissionManager/MissionCommandUIInfo.cc \
    src/MissionManager/MissionController.cc \
    src/MissionManager/MissionItem.cc \
    src/MissionManager/MissionManager.cc \
    src/MissionManager/MissionSettingsItem.cc \
    src/MissionManager/PlanElementController.cc \
    src/MissionManager/PlanCreator.cc \
    src/MissionManager/PlanManager.cc \
    src/MissionManager/PlanMasterController.cc \
    src/QmlControls/QGCFenceCircle.cc \
    src/QmlControls/QGCFencePolygon.cc \
    src/QmlControls/QGCMapCircle.cc \
    src/QmlControls/QGCMapPolygon.cc \
    src/QmlControls/QGCMapPolyline.cc \
    src/MissionManager/RallyPoint.cc \
    src/MissionManager/RallyPointController.cc \
    src/MissionManager/RallyPointManager.cc \
    src/MissionManager/SimpleMissionItem.cc \
    src/MissionManager/SpeedSection.cc \
    src/MissionManager/StructureScanComplexItem.cc \
    src/MissionManager/StructureScanPlanCreator.cc \
    src/MissionManager/SurveyComplexItem.cc \
    src/MissionManager/SurveyPlanCreator.cc \
    src/MissionManager/TakeoffMissionItem.cc \
    src/MissionManager/TransectStyleComplexItem.cc \
    src/MissionManager/VisualMissionItem.cc \
    src/MissionManager/VTOLLandingComplexItem.cc \
    src/PositionManager/PositionManager.cpp \
    src/PositionManager/SimulatedPosition.cc \
    src/Geo/QGCGeo.cc \
    src/Utilities/QGC.cc \
    src/Utilities/DeviceInfo.cc \
    src/QGCApplication.cc \
    src/Utilities/QGCCachedFileDownload.cc \
    src/Utilities/QGCFileDownload.cc \
    src/Utilities/QGCLoggingCategory.cc \
    src/QmlControls/QGCMapPalette.cc \
    src/QmlControls/QGCPalette.cc \
    src/QmlControls/QGCQGeoCoordinate.cc \
    src/Utilities/QGCTemporaryFile.cc \
    src/QGCToolbox.cc \
    src/QmlControls/AppMessages.cc \
    src/QmlControls/EditPositionDialogController.cc \
    src/QmlControls/FlightPathSegment.cc \
    src/QmlControls/HorizontalFactValueGrid.cc \
    src/QmlControls/InstrumentValueData.cc \
    src/QmlControls/FactValueGrid.cc \
    src/QmlControls/ParameterEditorController.cc \
    src/QmlControls/QGCFileDialogController.cc \
    src/QmlControls/QGCImageProvider.cc \
    src/QmlControls/QGroundControlQmlGlobal.cc \
    src/QmlControls/QmlObjectListModel.cc \
    src/QmlControls/QGCGeoBoundingCube.cc \
    src/QmlControls/RCChannelMonitorController.cc \
    src/QmlControls/RCToParamDialogController.cc \
    src/QmlControls/ScreenToolsController.cc \
    src/QmlControls/TerrainProfile.cc \
    src/QmlControls/ToolStripAction.cc \
    src/QmlControls/ToolStripActionList.cc \
    src/QtLocationPlugin/QMLControl/QGCMapEngineManager.cc \
    src/Settings/ADSBVehicleManagerSettings.cc \
    src/Settings/AppSettings.cc \
    src/Settings/AutoConnectSettings.cc \
    src/Settings/BatteryIndicatorSettings.cc \
    src/Settings/BrandImageSettings.cc \
    src/Settings/CustomMavlinkActionsSettings.cc \
    src/Settings/RemoteIDSettings.cc \
    src/Settings/FirmwareUpgradeSettings.cc \
    src/Settings/FlightMapSettings.cc \
    src/Settings/FlightModeSettings.cc \
    src/Settings/FlyViewSettings.cc \
    src/Settings/MapsSettings.cc \
    src/Settings/OfflineMapsSettings.cc \
    src/Settings/PlanViewSettings.cc \
    src/Settings/RTKSettings.cc \
    src/Settings/SettingsGroup.cc \
    src/Settings/SettingsManager.cc \
    src/Settings/UnitsSettings.cc \
    src/Settings/VideoSettings.cc \
    src/Utilities/ShapeFileHelper.cc \
    src/Utilities/SHPFileHelper.cc \
    src/Terrain/TerrainQuery.cc \
    src/Terrain/TerrainQueryAirMap.cc \
    src/Terrain/TerrainTile.cc \
    src/Terrain/TerrainTileManager.cc \
    src/Vehicle/Actuators/ActuatorActions.cc \
    src/Vehicle/Actuators/Actuators.cc \
    src/Vehicle/Actuators/ActuatorOutputs.cc \
    src/Vehicle/Actuators/ActuatorTesting.cc \
    src/Vehicle/Actuators/Common.cc \
    src/Vehicle/Actuators/GeometryImage.cc \
    src/Vehicle/Actuators/Mixer.cc \
    src/Vehicle/Actuators/MotorAssignment.cc \
    src/MAVLink/LibEvents/EventHandler.cc \
    src/MAVLink/LibEvents/HealthAndArmingCheckReport.cc \
    src/MAVLink/LibEvents/logging.cpp \
    src/Vehicle/Components/CompInfo.cc \
    src/Vehicle/Components/CompInfoActuators.cc \
    src/Vehicle/Components/CompInfoEvents.cc \
    src/Vehicle/Components/CompInfoParam.cc \
    src/Vehicle/Components/CompInfoGeneral.cc \
    src/Vehicle/Components/ComponentInformationCache.cc \
    src/Vehicle/Components/ComponentInformationManager.cc \
    src/Vehicle/Components/ComponentInformationTranslation.cc \
    src/Vehicle/FTPManager.cc \
    src/Vehicle/FactGroups/GPSRTKFactGroup.cc \
    src/MAVLink/ImageProtocolManager.cc \
    src/Vehicle/InitialConnectStateMachine.cc \
    src/Vehicle/MAVLinkLogManager.cc \
    src/MAVLink/MAVLinkStreamConfig.cc \
    src/Vehicle/MultiVehicleManager.cc \
    src/Vehicle/RemoteIDManager.cc \
    src/Utilities/StateMachine.cc \
    src/Vehicle/StandardModes.cc \
    src/MAVLink/SysStatusSensorInfo.cc \
    src/Vehicle/FactGroups/TerrainFactGroup.cc \
    src/Vehicle/TerrainProtocolHandler.cc \
    src/Vehicle/TrajectoryPoints.cc \
    src/Vehicle/Vehicle.cc \
    src/Vehicle/VehicleObjectAvoidance.cc \
    src/Vehicle/FactGroups/VehicleBatteryFactGroup.cc \
    src/Vehicle/FactGroups/VehicleClockFactGroup.cc \
    src/Vehicle/FactGroups/VehicleDistanceSensorFactGroup.cc \
    src/Vehicle/FactGroups/VehicleEstimatorStatusFactGroup.cc \
    src/Vehicle/FactGroups/VehicleLocalPositionFactGroup.cc \
    src/Vehicle/FactGroups/VehicleLocalPositionSetpointFactGroup.cc \
    src/Vehicle/FactGroups/VehicleGPSFactGroup.cc \
    src/Vehicle/FactGroups/VehicleGPS2FactGroup.cc \
    src/Vehicle/VehicleLinkManager.cc \
    src/Vehicle/FactGroups/VehicleSetpointFactGroup.cc \
    src/Vehicle/FactGroups/VehicleTemperatureFactGroup.cc \
    src/Vehicle/FactGroups/VehicleVibrationFactGroup.cc \
    src/Vehicle/FactGroups/VehicleHygrometerFactGroup.cc \
    src/Vehicle/FactGroups/VehicleGeneratorFactGroup.cc \
    src/Vehicle/FactGroups/VehicleEFIFactGroup.cc \
    src/Vehicle/FactGroups/VehicleWindFactGroup.cc \
    src/VehicleSetup/JoystickConfigController.cc \
    src/Comms/LinkConfiguration.cc \
    src/Comms/LinkInterface.cc \
    src/Comms/LinkManager.cc \
    src/Comms/LogReplayLink.cc \
    src/Comms/MAVLinkProtocol.cc \
    src/MAVLink/QGCMAVLink.cc \
    src/MAVLink/MAVLinkFTP.cc \
    src/MAVLink/StatusTextHandler.cc \
    src/Comms/TCPLink.cc \
    src/Comms/UDPLink.cc \
    src/Comms/UdpIODevice.cc \
    src/main.cc \
    src/AnalyzeView/GeoTagController.cc \
    src/AnalyzeView/GeoTagWorker.cc \
    src/AnalyzeView/ExifParser.cc \
    src/Viewer3D/CityMapGeometry.cc \
    src/Viewer3D/OsmParser.cc \
    src/Viewer3D/Viewer3DQmlBackend.cc \
    src/Viewer3D/Viewer3DUtils.cc \
    src/Viewer3D/Viewer3DManager.cc \
    src/Settings/Viewer3DSettings.cc \
    src/Viewer3D/Viewer3DTileReply.cc \
    src/Viewer3D/Viewer3DTerrainGeometry.cc \
    src/Viewer3D/Viewer3DTerrainTexture.cc \
    src/Viewer3D/Viewer3DTileQuery.cc \
    src/Viewer3D/OsmParserThread.cc \

DebugBuild {
SOURCES += \
    src/Comms/MockLink/MockLink.cc \
    src/Comms/MockLink/MockLinkFTP.cc \
    src/Comms/MockLink/MockLinkMissionItemHandler.cc \
}

!contains(DEFINES, NO_SERIAL_LINK) {
SOURCES += \
    src/Comms/QGCSerialPortInfo.cc \
    src/Comms/SerialLink.cc \
}

contains(DEFINES, QGC_ENABLE_BLUETOOTH) {
    SOURCES += \
    src/Comms/BluetoothLink.cc \
}

!iosBuild {
SOURCES += \
    src/GPS/Drivers/src/gps_helper.cpp \
    src/GPS/Drivers/src/rtcm.cpp \
    src/GPS/Drivers/src/ashtech.cpp \
    src/GPS/Drivers/src/ubx.cpp \
    src/GPS/Drivers/src/sbf.cpp \
    src/GPS/GPSManager.cc \
    src/GPS/GPSProvider.cc \
    src/GPS/RTCMMavlink.cc
}

!MobileBuild {
SOURCES += \
    src/Joystick/JoystickSDL.cc \
    src/RunGuard.cc \
}

#
# Firmware Plugin Support
#

INCLUDEPATH += \
    src/AutoPilotPlugins/Common \
    src/AutoPilotPlugins/Generic \
    src/FirmwarePlugin \
    src/VehicleSetup \

HEADERS+= \
    src/AutoPilotPlugins/AutoPilotPlugin.h \
    src/AutoPilotPlugins/Common/ESP8266Component.h \
    src/AutoPilotPlugins/Common/ESP8266ComponentController.h \
    src/AutoPilotPlugins/Common/MotorComponent.h \
    src/AutoPilotPlugins/Common/RadioComponentController.h \
    src/AutoPilotPlugins/Common/SyslinkComponent.h \
    src/AutoPilotPlugins/Common/SyslinkComponentController.h \
    src/AutoPilotPlugins/Generic/GenericAutoPilotPlugin.h \
    src/FirmwarePlugin/CameraMetaData.h \
    src/FirmwarePlugin/FirmwarePlugin.h \
    src/FirmwarePlugin/FirmwarePluginFactory.h \
    src/FirmwarePlugin/FirmwarePluginManager.h \
    src/VehicleSetup/VehicleComponent.h \

!iosBuild { !contains(DEFINES, NO_SERIAL_LINK) {
    HEADERS += \
        src/VehicleSetup/Bootloader.h \
        src/VehicleSetup/FirmwareImage.h \
        src/VehicleSetup/FirmwareUpgradeController.h \
        src/VehicleSetup/PX4FirmwareUpgradeThread.h \
}}

SOURCES += \
    src/AutoPilotPlugins/AutoPilotPlugin.cc \
    src/AutoPilotPlugins/Common/ESP8266Component.cc \
    src/AutoPilotPlugins/Common/ESP8266ComponentController.cc \
    src/AutoPilotPlugins/Common/MotorComponent.cc \
    src/AutoPilotPlugins/Common/RadioComponentController.cc \
    src/AutoPilotPlugins/Common/SyslinkComponent.cc \
    src/AutoPilotPlugins/Common/SyslinkComponentController.cc \
    src/AutoPilotPlugins/Generic/GenericAutoPilotPlugin.cc \
    src/FirmwarePlugin/CameraMetaData.cc \
    src/FirmwarePlugin/FirmwarePlugin.cc \
    src/FirmwarePlugin/FirmwarePluginFactory.cc \
    src/FirmwarePlugin/FirmwarePluginManager.cc \
    src/VehicleSetup/VehicleComponent.cc \

!iosBuild { !contains(DEFINES, NO_SERIAL_LINK) {
    SOURCES += \
        src/VehicleSetup/Bootloader.cc \
        src/VehicleSetup/FirmwareImage.cc \
        src/VehicleSetup/FirmwareUpgradeController.cc \
        src/VehicleSetup/PX4FirmwareUpgradeThread.cc \
}}

# ArduPilot Specific

ArdupilotEnabled {
    HEADERS += \
        src/Settings/APMMavlinkStreamRateSettings.h \

    SOURCES += \
        src/Settings/APMMavlinkStreamRateSettings.cc \
}

# ArduPilot FirmwarePlugin

APMFirmwarePlugin {
    RESOURCES *= src/FirmwarePlugin/APM/APMResources.qrc

    INCLUDEPATH += \
        src/AutoPilotPlugins/APM \
        src/FirmwarePlugin/APM \

    HEADERS += \
        src/AutoPilotPlugins/APM/APMAirframeComponent.h \
        src/AutoPilotPlugins/APM/APMAirframeComponentController.h \
        src/AutoPilotPlugins/APM/APMAutoPilotPlugin.h \
        src/AutoPilotPlugins/APM/APMCameraComponent.h \
        src/AutoPilotPlugins/APM/APMFlightModesComponent.h \
        src/AutoPilotPlugins/APM/APMFlightModesComponentController.h \
        src/AutoPilotPlugins/APM/APMFollowComponent.h \
        src/AutoPilotPlugins/APM/APMFollowComponentController.h \
        src/AutoPilotPlugins/APM/APMHeliComponent.h \
        src/AutoPilotPlugins/APM/APMLightsComponent.h \
        src/AutoPilotPlugins/APM/APMSubFrameComponent.h \
        src/AutoPilotPlugins/APM/APMMotorComponent.h \
        src/AutoPilotPlugins/APM/APMPowerComponent.h \
        src/AutoPilotPlugins/APM/APMRadioComponent.h \
        src/AutoPilotPlugins/APM/APMSafetyComponent.h \
        src/AutoPilotPlugins/APM/APMSensorsComponent.h \
        src/AutoPilotPlugins/APM/APMSensorsComponentController.h \
        src/AutoPilotPlugins/APM/APMSubMotorComponentController.h \
        src/AutoPilotPlugins/APM/APMTuningComponent.h \
        src/AutoPilotPlugins/APM/APMRemoteSupportComponent.h \
        src/FirmwarePlugin/APM/APMFirmwarePlugin.h \
        src/FirmwarePlugin/APM/APMParameterMetaData.h \
        src/FirmwarePlugin/APM/ArduCopterFirmwarePlugin.h \
        src/FirmwarePlugin/APM/ArduPlaneFirmwarePlugin.h \
        src/FirmwarePlugin/APM/ArduRoverFirmwarePlugin.h \
        src/FirmwarePlugin/APM/ArduSubFirmwarePlugin.h \

    SOURCES += \
        src/AutoPilotPlugins/APM/APMAirframeComponent.cc \
        src/AutoPilotPlugins/APM/APMAirframeComponentController.cc \
        src/AutoPilotPlugins/APM/APMAutoPilotPlugin.cc \
        src/AutoPilotPlugins/APM/APMCameraComponent.cc \
        src/AutoPilotPlugins/APM/APMFlightModesComponent.cc \
        src/AutoPilotPlugins/APM/APMFlightModesComponentController.cc \
        src/AutoPilotPlugins/APM/APMFollowComponent.cc \
        src/AutoPilotPlugins/APM/APMFollowComponentController.cc \
        src/AutoPilotPlugins/APM/APMHeliComponent.cc \
        src/AutoPilotPlugins/APM/APMLightsComponent.cc \
        src/AutoPilotPlugins/APM/APMSubFrameComponent.cc \
        src/AutoPilotPlugins/APM/APMMotorComponent.cc \
        src/AutoPilotPlugins/APM/APMPowerComponent.cc \
        src/AutoPilotPlugins/APM/APMRadioComponent.cc \
        src/AutoPilotPlugins/APM/APMSafetyComponent.cc \
        src/AutoPilotPlugins/APM/APMSensorsComponent.cc \
        src/AutoPilotPlugins/APM/APMSensorsComponentController.cc \
        src/AutoPilotPlugins/APM/APMSubMotorComponentController.cc \
        src/AutoPilotPlugins/APM/APMTuningComponent.cc \
        src/AutoPilotPlugins/APM/APMRemoteSupportComponent.cc \
        src/FirmwarePlugin/APM/APMFirmwarePlugin.cc \
        src/FirmwarePlugin/APM/APMParameterMetaData.cc \
        src/FirmwarePlugin/APM/ArduCopterFirmwarePlugin.cc \
        src/FirmwarePlugin/APM/ArduPlaneFirmwarePlugin.cc \
        src/FirmwarePlugin/APM/ArduRoverFirmwarePlugin.cc \
        src/FirmwarePlugin/APM/ArduSubFirmwarePlugin.cc \
}

APMFirmwarePluginFactory {
    HEADERS   += src/FirmwarePlugin/APM/APMFirmwarePluginFactory.h
    SOURCES   += src/FirmwarePlugin/APM/APMFirmwarePluginFactory.cc
}

# PX4 FirmwarePlugin

PX4FirmwarePlugin {
    RESOURCES *= src/FirmwarePlugin/PX4/PX4Resources.qrc

    INCLUDEPATH += \
        src/AutoPilotPlugins/PX4 \
        src/FirmwarePlugin/PX4 \

    HEADERS+= \
        src/AutoPilotPlugins/PX4/ActuatorComponent.h \
        src/AutoPilotPlugins/PX4/AirframeComponent.h \
        src/AutoPilotPlugins/PX4/AirframeComponentAirframes.h \
        src/AutoPilotPlugins/PX4/AirframeComponentController.h \
        src/AutoPilotPlugins/PX4/CameraComponent.h \
        src/AutoPilotPlugins/PX4/FlightModesComponent.h \
        src/AutoPilotPlugins/PX4/PX4AirframeLoader.h \
        src/AutoPilotPlugins/PX4/PX4AutoPilotPlugin.h \
        src/AutoPilotPlugins/PX4/PX4FlightBehavior.h \
        src/AutoPilotPlugins/PX4/PX4RadioComponent.h \
        src/AutoPilotPlugins/PX4/PX4SimpleFlightModesController.h \
        src/AutoPilotPlugins/PX4/PX4TuningComponent.h \
        src/AutoPilotPlugins/PX4/PowerComponent.h \
        src/AutoPilotPlugins/PX4/PowerComponentController.h \
        src/AutoPilotPlugins/PX4/SafetyComponent.h \
        src/AutoPilotPlugins/PX4/SensorsComponent.h \
        src/AutoPilotPlugins/PX4/SensorsComponentController.h \
        src/FirmwarePlugin/PX4/PX4FirmwarePlugin.h \
        src/FirmwarePlugin/PX4/PX4ParameterMetaData.h \

    SOURCES += \
        src/AutoPilotPlugins/PX4/ActuatorComponent.cc \
        src/AutoPilotPlugins/PX4/AirframeComponent.cc \
        src/AutoPilotPlugins/PX4/AirframeComponentAirframes.cc \
        src/AutoPilotPlugins/PX4/AirframeComponentController.cc \
        src/AutoPilotPlugins/PX4/CameraComponent.cc \
        src/AutoPilotPlugins/PX4/FlightModesComponent.cc \
        src/AutoPilotPlugins/PX4/PX4AirframeLoader.cc \
        src/AutoPilotPlugins/PX4/PX4AutoPilotPlugin.cc \
        src/AutoPilotPlugins/PX4/PX4FlightBehavior.cc \
        src/AutoPilotPlugins/PX4/PX4RadioComponent.cc \
        src/AutoPilotPlugins/PX4/PX4SimpleFlightModesController.cc \
        src/AutoPilotPlugins/PX4/PX4TuningComponent.cc \
        src/AutoPilotPlugins/PX4/PowerComponent.cc \
        src/AutoPilotPlugins/PX4/PowerComponentController.cc \
        src/AutoPilotPlugins/PX4/SafetyComponent.cc \
        src/AutoPilotPlugins/PX4/SensorsComponent.cc \
        src/AutoPilotPlugins/PX4/SensorsComponentController.cc \
        src/FirmwarePlugin/PX4/PX4FirmwarePlugin.cc \
        src/FirmwarePlugin/PX4/PX4ParameterMetaData.cc \
}

PX4FirmwarePluginFactory {
    HEADERS   += src/FirmwarePlugin/PX4/PX4FirmwarePluginFactory.h
    SOURCES   += src/FirmwarePlugin/PX4/PX4FirmwarePluginFactory.cc
}

# Fact System code

INCLUDEPATH += \
    src/FactSystem \
    src/FactSystem/FactControls \

HEADERS += \
    src/FactSystem/Fact.h \
    src/FactSystem/FactControls/FactPanelController.h \
    src/FactSystem/FactGroup.h \
    src/FactSystem/FactMetaData.h \
    src/FactSystem/FactSystem.h \
    src/FactSystem/FactValueSliderListModel.h \
    src/FactSystem/ParameterManager.h \
    src/FactSystem/SettingsFact.h \

SOURCES += \
    src/FactSystem/Fact.cc \
    src/FactSystem/FactControls/FactPanelController.cc \
    src/FactSystem/FactGroup.cc \
    src/FactSystem/FactMetaData.cc \
    src/FactSystem/FactSystem.cc \
    src/FactSystem/FactValueSliderListModel.cc \
    src/FactSystem/ParameterManager.cc \
    src/FactSystem/SettingsFact.cc \

#-------------------------------------------------------------------------------------
# MAVLink Inspector

contains (DEFINES, QGC_DISABLE_MAVLINK_INSPECTOR) {
    message("Disable mavlink inspector")
} else {
    HEADERS += \
        src/AnalyzeView/MAVLinkInspectorController.h \
        src/AnalyzeView/MAVLinkChartController.h
    SOURCES += \
        src/AnalyzeView/MAVLinkInspectorController.cc \
        src/AnalyzeView/MAVLinkChartController.cc
    QT += \
        charts
}

#-------------------------------------------------------------------------------------
# Airlink
contains (DEFINES, QGC_AIRLINK_DISABLED) {
    message("AirLink disabled")
} else {
    message("AirLink enabled")
    INCLUDEPATH += \
        src/AirLink

    HEADERS += \
        src/AirLink/AirlinkLink.h \
        src/AirLink/AirLinkManager.h

    SOURCES += \
        src/AirLink/AirlinkLink.cc \
        src/AirLink/AirLinkManager.cc
}

#-------------------------------------------------------------------------------------
# Video Streaming

INCLUDEPATH += \
    src/VideoManager

HEADERS += \
    src/VideoManager/SubtitleWriter.h \
    src/VideoManager/VideoManager.h

SOURCES += \
    src/VideoManager/SubtitleWriter.cc \
    src/VideoManager/VideoManager.cc

contains (CONFIG, DISABLE_VIDEOSTREAMING) {
    message("Skipping support for video streaming (manual override from command line)")
# Otherwise the user can still disable this feature in the user_config.pri file.
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, DISABLE_VIDEOSTREAMING) {
    message("Skipping support for video streaming (manual override from user_config.pri)")
} else {
    QT += \
        opengl \
        gui-private
    include(src/VideoReceiver/VideoReceiver.pri)
}

!VideoEnabled {
    INCLUDEPATH += \
        src/VideoReceiver

    HEADERS += \
        src/VideoManager/GLVideoItemStub.h \
        src/VideoReceiver/VideoReceiver.h

    SOURCES += \
        src/VideoManager/GLVideoItemStub.cc
}

#-------------------------------------------------------------------------------------
# Android

AndroidBuild {
    contains (CONFIG, DISABLE_BUILTIN_ANDROID) {
        message("Skipping builtin support for Android")
    } else {
        include(android.pri)
    }
}

#-------------------------------------------------------------------------------------
#
# Localization
#

TRANSLATIONS += $$files($$PWD/translations/qgc_*.ts)
CONFIG+=lrelease embed_translations

#-------------------------------------------------------------------------------------
#
# Post link configuration
#

contains (CONFIG, QGC_DISABLE_BUILD_SETUP) {
    message("Disable standard build setup")
} else {
    include(QGCPostLinkCommon.pri)
}

#
# Installer targets
#

contains (CONFIG, QGC_DISABLE_INSTALLER_SETUP) {
    message("Disable standard installer setup")
} else {
    include(QGCPostLinkInstaller.pri)
}

DISTFILES += \
    src/QmlControls/QGroundControl/Specific/qmldir

#
# Steps for "install" target on Linux
#
LinuxBuild {
    target.path = $${PREFIX}/bin/

    share_qgroundcontrol.path = $${PREFIX}/share/qgroundcontrol/
    share_qgroundcontrol.files = $${IN_PWD}/resources/

    share_icons.path = $${PREFIX}/share/icons/hicolor/128x128/apps/
    share_icons.files = $${IN_PWD}/resources/icons/qgroundcontrol.png
    share_metainfo.path = $${PREFIX}/share/metainfo/
    share_metainfo.files = $${IN_PWD}/deploy/linux/org.mavlink.qgroundcontrol.metainfo.xml
    share_applications.path = $${PREFIX}/share/applications/
    share_applications.files = $${IN_PWD}/deploy/linux/qgroundcontrol.desktop

    INSTALLS += target share_qgroundcontrol share_icons share_metainfo share_applications
}

# UTM Adapter Enabled
contains (DEFINES, CONFIG_UTM_ADAPTER) {
    message("UTM enabled")

    #-- To test with UTM Adapter Enabled Flag
    INCLUDEPATH += \
        src/UTMSP \

    RESOURCES += \
        src/UTMSP/utmsp.qrc

    HEADERS += \
        src/UTMSP/UTMSPLogger.h \
        src/UTMSP/UTMSPRestInterface.h \
        src/UTMSP/UTMSPBlenderRestInterface.h \
        src/UTMSP/UTMSPAuthorization.h \
        src/UTMSP/UTMSPNetworkRemoteIDManager.h \
        src/UTMSP/UTMSPAircraft.h \
        src/UTMSP/UTMSPFlightDetails.h \
        src/UTMSP/UTMSPOperator.h \
        src/UTMSP/UTMSPFlightPlanManager.h \
        src/UTMSP/UTMSPServiceController.h \
        src/UTMSP/UTMSPVehicle.h \
        src/UTMSP/UTMSPManager.h

    SOURCES += \
        src/UTMSP/UTMSPRestInterface.cpp \
        src/UTMSP/UTMSPBlenderRestInterface.cpp \
        src/UTMSP/UTMSPAuthorization.cpp \
        src/UTMSP/UTMSPNetworkRemoteIDManager.cpp \
        src/UTMSP/UTMSPAircraft.cpp \
        src/UTMSP/UTMSPFlightDetails.cpp \
        src/UTMSP/UTMSPOperator.cpp \
        src/UTMSP/UTMSPFlightPlanManager.cpp \
        src/UTMSP/UTMSPServiceController.cpp \
        src/UTMSP/UTMSPVehicle.cpp \
        src/UTMSP/UTMSPManager.cpp
}
else {
   #-- Dummy UTM Adapter resource file created to override UTM adapter qml files
   INCLUDEPATH += \
       src/UTMSP/dummy
   RESOURCES += \
       src/UTMSP/dummy/utmsp_dummy.qrc
}

QT += testlib
# include(test/QGCTest.pri)
