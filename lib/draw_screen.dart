import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as imglib;

class Draw extends StatefulWidget {
  @override
  _DrawState createState() => _DrawState();
}

class _DrawState extends State<Draw> {
  GlobalKey _globalKey = GlobalKey();
  ByteData _image;
  Size _canvasSize;
  Color selectedColor = Colors.black;
  Color pickerColor = Colors.black;
  double strokeWidth = 3.0;
  List<DrawingPoints> points = List();
  bool showBottomList = false;
  double opacity = 1.0;
  StrokeCap strokeCap = (Platform.isAndroid) ? StrokeCap.butt : StrokeCap.round;
  SelectedMode selectedMode = SelectedMode.StrokeWidth;
  List<Color> colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.amber,
    Colors.black
  ];
  @override
  Widget build(BuildContext context) {
    int _deviceId = -1;
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50.0),
                color: Colors.greenAccent),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                          icon: Icon(Icons.album),
                          onPressed: () {
                            setState(() {
                              if (selectedMode == SelectedMode.StrokeWidth)
                                showBottomList = !showBottomList;
                              selectedMode = SelectedMode.StrokeWidth;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.opacity),
                          onPressed: () {
                            setState(() {
                              if (selectedMode == SelectedMode.Opacity)
                                showBottomList = !showBottomList;
                              selectedMode = SelectedMode.Opacity;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.color_lens),
                          onPressed: () {
                            setState(() {
                              if (selectedMode == SelectedMode.Color)
                                showBottomList = !showBottomList;
                              selectedMode = SelectedMode.Color;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.delete_sweep),
                          onPressed: () {
                            setState(() {
                              showBottomList = false;
                              selectedMode = SelectedMode.Eraser;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              showBottomList = false;
                              points.clear();
                              _image = null;
                            });
                          }),
                    ],
                  ),
                  Visibility(
                    child: (selectedMode == SelectedMode.Color)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: getColorList(),
                          )
                        : Slider(
                            value: (selectedMode == SelectedMode.StrokeWidth)
                                ? strokeWidth
                                : opacity,
                            max: (selectedMode == SelectedMode.StrokeWidth)
                                ? 50.0
                                : 1.0,
                            min: 0.0,
                            onChanged: (val) {
                              setState(() {
                                if (selectedMode == SelectedMode.StrokeWidth)
                                  strokeWidth = val;
                                else
                                  opacity = val;
                              });
                            }),
                    visible: showBottomList,
                  ),
                ],
              ),
            )),
      ),
      body: Listener(
        onPointerSignal: (PointerEvent details) {
          print("onPointerSignal");
          print(details);
        },
        onPointerMove: (PointerEvent details) {
          print("onPointerMove");
          print(details.device);
          print(details.localPosition);
          if (_deviceId == -1) {
            _deviceId = details.device;
          }
          if (_deviceId != details.device) {
            return null;
          }
          setState(() {
            bool _isEraser = this.selectedMode == SelectedMode.Eraser;
            print(this.selectedColor);
            RenderBox renderBox = context.findRenderObject();
            points.add(DrawingPoints(
                points: renderBox.globalToLocal(details.localPosition),
                paint: Paint()
                  ..strokeCap = strokeCap
                  ..isAntiAlias = true
                  ..color = _isEraser
                      ? Colors.transparent
                      : selectedColor.withOpacity(opacity)
                  ..strokeWidth = _isEraser ? strokeWidth + 20 : strokeWidth
                  ..blendMode = _isEraser ? BlendMode.clear : BlendMode.src));
            print(points.last.paint);
          });
        },
        onPointerUp: (PointerEvent details) {
          print("onPointerUp");
          print(details);
          setState(() {
            _deviceId = -1;
            // points.add(null);
            setImage();
          });
        },
        onPointerCancel: (PointerEvent details) {
          print("onPointerCancel");
          print(details);
          setState(() {
            _deviceId = -1;
            // points.add(null);
            setImage();
          });
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                "assets/bg.jpg",
                repeat: ImageRepeat.repeat,
              ),
            ),
            _image != null
                ? Image.memory(
                    _image.buffer.asUint8List(),
                  )
                : Container(),
            CustomPaint(
              key: _globalKey,
              size: Size.infinite,
              painter: DrawingPainter(
                pointsList: points,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void setImage() async {
    ui.Image renderedImage = await this.rendered;
    ByteData newImage =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    ByteData composedImage =
        await compositeImage(_image, newImage, _canvasSize);

    setState(() {
      _image = composedImage;
      points.clear();
    });
  }

  Future<ui.Image> get rendered {
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    DrawingPainter painter = DrawingPainter(pointsList: points);

    RenderBox box = _globalKey.currentContext.findRenderObject();
    _canvasSize = box.size;
    painter.paint(canvas, _canvasSize);
    return recorder
        .endRecording()
        .toImage(_canvasSize.width.toInt(), _canvasSize.height.toInt());
  }

  Future<ByteData> compositeImage(
      ByteData currentImage, ByteData newImage, Size size) async {
    imglib.Image srcImg = imglib.Image.fromBytes(
        size.width.toInt(), size.height.toInt(), newImage.buffer.asUint8List());

    if (currentImage == null) {
      return ByteData.view(srcImg.data.buffer);
    }

    imglib.Image dstImg = imglib.Image.fromBytes(size.width.toInt(),
        size.height.toInt(), currentImage.buffer.asUint8List());

    imglib.Image compImg = imglib.drawImage(
        imglib.decodePng(dstImg.data.buffer.asUint8List()),
        imglib.decodePng(srcImg.data.buffer.asUint8List()));

    Uint8List resultImg = imglib.encodePng(compImg) as Uint8List;

    return ByteData.sublistView(resultImg.buffer.asUint8List());
  }

  getColorList() {
    List<Widget> listWidget = List();
    for (Color color in colors) {
      listWidget.add(colorCircle(color));
    }
    Widget colorPicker = GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          child: AlertDialog(
            title: const Text('Pick a color!'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  pickerColor = color;
                },
                showLabel: true,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: const Text('Save'),
                onPressed: () {
                  setState(() => selectedColor = pickerColor);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
      child: ClipOval(
        child: Container(
          padding: const EdgeInsets.only(bottom: 16.0),
          height: 36,
          width: 36,
          decoration: BoxDecoration(
              gradient: LinearGradient(
            colors: [Colors.red, Colors.green, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )),
        ),
      ),
    );
    listWidget.add(colorPicker);
    return listWidget;
  }

  Widget colorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: ClipOval(
        child: Container(
          padding: const EdgeInsets.only(bottom: 16.0),
          height: 36,
          width: 36,
          color: color,
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  DrawingPainter({this.pointsList});
  List<DrawingPoints> pointsList;
  List<Offset> offsetPoints = List();
  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    print(rect);
    canvas.saveLayer(rect, Paint());
    for (int i = 0; i < pointsList.length - 1; i++) {
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        canvas.drawLine(pointsList[i].points, pointsList[i + 1].points,
            pointsList[i].paint);
      } else if (pointsList[i] != null && pointsList[i + 1] == null) {
        offsetPoints.clear();
        offsetPoints.add(pointsList[i].points);
        offsetPoints.add(Offset(
            pointsList[i].points.dx + 0.1, pointsList[i].points.dy + 0.1));
        canvas.drawPoints(
            ui.PointMode.points, offsetPoints, pointsList[i].paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class DrawingPoints {
  Paint paint;
  Offset points;
  DrawingPoints({this.points, this.paint});
}

enum SelectedMode { StrokeWidth, Opacity, Color, Eraser }
