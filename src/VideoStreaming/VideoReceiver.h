/****************************************************************************
 *
 *   (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

/**
 * @file
 *   @brief QGC Video Receiver
 *   @author Gus Grubba <mavlink@grubba.com>
 */

#pragma once

#include "QGCLoggingCategory.h"
#include <QObject>
#include <QTimer>
#include <QTcpSocket>

#if defined(QGC_GST_STREAMING)
#include <gst/gst.h>
#endif

#include <QQuickItem>

Q_DECLARE_LOGGING_CATEGORY(VideoReceiverLog)

class VideoSettings;
class VideoSettings2;

class VideoReceiver : public QObject
{
    Q_OBJECT

public:
    enum VideoEncoding {
        H264_SW = 1,
        H264_HW = 2,
        H265_SW = 3,
        H265_HW = 4
    };

#if defined(QGC_GST_STREAMING)
    Q_PROPERTY(bool             recording           READ    recording           NOTIFY recordingChanged)
#endif
    Q_PROPERTY(bool             videoRunning        READ    videoRunning        NOTIFY  videoRunningChanged)
    Q_PROPERTY(QString          imageFile           READ    imageFile           NOTIFY  imageFileChanged)
    Q_PROPERTY(QString          videoFile           READ    videoFile           NOTIFY  videoFileChanged)
    Q_PROPERTY(bool             showFullScreen      READ    showFullScreen      WRITE   setShowFullScreen     NOTIFY showFullScreenChanged)
    Q_PROPERTY(VideoSettings2*  settings READ settings CONSTANT)

    explicit VideoReceiver(QObject* parent = nullptr);
    ~VideoReceiver();

#if defined(QGC_GST_STREAMING)
    virtual bool            recording       () { return _recording; }
    // Those two methods are sending
    Q_INVOKABLE GstElement *pipeline() const;
    Q_INVOKABLE GstElement *videoSink() const;
#endif

    virtual bool            videoRunning    () { return _videoRunning; }
    virtual QString         imageFile       () { return _imageFile; }
    virtual QString         videoFile       () { return _videoFile; }
    virtual bool            showFullScreen  () { return _showFullScreen; }

    virtual void            grabImage       (QString imageFile);

    virtual void        setShowFullScreen   (bool show) { _showFullScreen = show; emit showFullScreenChanged(); }

    void                  setVideoDecoder   (VideoEncoding encoding);
    VideoSettings2 *settings() const;

signals:
    void videoRunningChanged                ();
    void imageFileChanged                   ();
    void videoFileChanged                   ();
    void showFullScreenChanged              ();
#if defined(QGC_GST_STREAMING)
    void recordingChanged                   ();
    void msgErrorReceived                   ();
    void msgEOSReceived                     ();
    void msgStateChangedReceived            ();
    void gotFirstRecordingKeyFrame          ();
#endif


public slots:
    virtual void start                      ();
    virtual void stop                       ();
    virtual void setUri                     (const QString& uri);
    virtual void stopRecording              ();
    virtual void startRecording             (const QString& videoFile = QString());

protected slots:
    virtual void _updateTimer               ();
#if defined(QGC_GST_STREAMING)
    virtual void _restart_timeout           ();
    virtual void _handleError               ();
    virtual void _handleEOS                 ();
    virtual void _handleStateChanged        ();
#endif

protected:
#if defined(QGC_GST_STREAMING)

    typedef struct
    {
        GstPad*         teepad;
        GstElement*     queue;
        GstElement*     mux;
        GstElement*     filesink;
        GstElement*     parse;
        gboolean        removing;
    } Sink;

    bool                _running;
    bool                _recording;
    bool                _streaming;
    bool                _starting;
    bool                _stopping;
    bool                _stop;
    Sink*               _sink;
    GstElement*         _tee;

    static gboolean             _onBusMessage           (GstBus* bus, GstMessage* message, gpointer user_data);
    static GstPadProbeReturn    _unlinkCallBack         (GstPad* pad, GstPadProbeInfo* info, gpointer user_data);
    static GstPadProbeReturn    _keyframeWatch          (GstPad* pad, GstPadProbeInfo* info, gpointer user_data);

    virtual void                _detachRecordingBranch  (GstPadProbeInfo* info);
    virtual void                _shutdownRecordingBranch();
    virtual void                _shutdownPipeline       ();
    virtual void                _cleanupOldVideos       ();

    GstElement*     _pipeline;
    GstElement*     _pipelineStopRec;
    GstElement*     _videoSink;
    GstElement*     _glUpload;

    //-- Wait for Video Server to show up before starting
    QTimer          _frameTimer;
    QTimer          _restart_timer;
    int             _restart_time_ms;

    //-- RTSP UDP reconnect timeout
    uint64_t        _udpReconnect_us;
#endif

    QString         _uri;
    QString         _imageFile;
    QString         _videoFile;
    bool            _videoRunning;
    bool            _showFullScreen;
    VideoSettings*  _videoSettings;
    const char*     _depayName;
    const char*     _parserName;
    bool            _tryWithHardwareDecoding = true;
    const char*     _hwDecoderName;
    const char*     _swDecoderName;
    VideoSettings2 *_videoSettings2;
};

