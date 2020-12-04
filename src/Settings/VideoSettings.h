/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#ifndef VideoSettings_H
#define VideoSettings_H

#include "SettingsGroup.h"

class VideoSettings : public SettingsGroup
{
    Q_OBJECT

public:
    VideoSettings(QObject* parent = nullptr);
    DEFINE_SETTING_NAME_GROUP()

    DEFINE_SETTINGFACT(videoSource)
    DEFINE_SETTINGFACT(udpPort)
    DEFINE_SETTINGFACT(tcpUrl)
    DEFINE_SETTINGFACT(rtspUrl)
    DEFINE_SETTINGFACT(aspectRatio)
    DEFINE_SETTINGFACT(videoFit)
    DEFINE_SETTINGFACT(gridLines)
    DEFINE_SETTINGFACT(showRecControl)
    DEFINE_SETTINGFACT(recordingFormat)
    DEFINE_SETTINGFACT(maxVideoSize)
    DEFINE_SETTINGFACT(enableStorageLimit)
    DEFINE_SETTINGFACT(rtspTimeout)
    DEFINE_SETTINGFACT(streamEnabled)
    DEFINE_SETTINGFACT(disableWhenDisarmed)
    DEFINE_SETTINGFACT(lowLatencyMode)
    DEFINE_SETTINGFACT(forceVideoDecoder)

    Q_PROPERTY(bool     streamConfigured        READ streamConfigured       NOTIFY streamConfiguredChanged)
    Q_PROPERTY(QString  rtspVideoSource         READ rtspVideoSource        CONSTANT)
    Q_PROPERTY(QString  udp264VideoSource       READ udp264VideoSource      CONSTANT)
    Q_PROPERTY(QString  udp265VideoSource       READ udp265VideoSource      CONSTANT)
    Q_PROPERTY(QString  tcpVideoSource          READ tcpVideoSource         CONSTANT)
    Q_PROPERTY(QString  mpegtsVideoSource       READ mpegtsVideoSource      CONSTANT)
    Q_PROPERTY(QString  disabledVideoSource     READ disabledVideoSource    CONSTANT)

    Q_PROPERTY(QString  defaultVideoDecoder     READ defaultVideoDecoder    CONSTANT)
    Q_PROPERTY(QString  softwareVideoDecoder    READ softwareVideoDecoder   CONSTANT)
    Q_PROPERTY(QString  nvidiaVideoDecoder      READ nvidiaVideoDecoder     CONSTANT)
    Q_PROPERTY(QString  vaapiVideoDecoder       READ vaapiVideoDecoder      CONSTANT)
    Q_PROPERTY(QString  d3d11VideoDecoder       READ d3d11VideoDecoder      CONSTANT)

    bool     streamConfigured       ();
    QString  rtspVideoSource        () { return videoSourceRTSP; }
    QString  udp264VideoSource      () { return videoSourceUDPH264; }
    QString  udp265VideoSource      () { return videoSourceUDPH265; }
    QString  tcpVideoSource         () { return videoSourceTCP; }
    QString  mpegtsVideoSource      () { return videoSourceMPEGTS; }
    QString  disabledVideoSource    () { return videoDisabled; }

    QString defaultVideoDecoder     () { return forceVideoDecoderDefault; }
    QString softwareVideoDecoder    () { return forceVideoDecoderSoftware; }
    QString nvidiaVideoDecoder      () { return forceVideoDecoderNVIDIA; }
    QString vaapiVideoDecoder       () { return forceVideoDecoderVAAPI; }
    QString d3d11VideoDecoder       () { return forceVideoDecoderD3D11; }

    static const char* videoSourceNoVideo;
    static const char* videoDisabled;
    static const char* videoSourceUDPH264;
    static const char* videoSourceUDPH265;
    static const char* videoSourceRTSP;
    static const char* videoSourceTCP;
    static const char* videoSourceMPEGTS;
    static const char* videoSource3DRSolo;
    static const char* videoSourceParrotDiscovery;

    static const char* forceVideoDecoderDefault;
    static const char* forceVideoDecoderSoftware;
    static const char* forceVideoDecoderNVIDIA;
    static const char* forceVideoDecoderVAAPI;
    static const char* forceVideoDecoderD3D11;

signals:
    void streamConfiguredChanged    (bool configured);

private slots:
    void _configChanged             (QVariant value);

private:
    void _setDefaults               ();

private:
    bool _noVideo = false;

};

#endif
