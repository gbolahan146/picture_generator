import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picture_generator/drawingarea.dart';
import 'dart:ui' as ui;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _loading = true;
  List<DrawingArea> points = [];
  Widget imageOutput;
  ByteData imgBytes = ByteData(1024);
  var img1;

  void saveToImage(List<DrawingArea> points) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromPoints(Offset(0.0, 0.0), Offset(200, 200)));
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    final paint2 = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    canvas.drawRect(Rect.fromLTWH(0, 0, 256, 256), paint2);

    for (int i = 0; i < points.length; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i].point, points[i + 1].point, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(256, 256);

    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final listBytes = Uint8List.view(pngBytes.buffer);

    // ignore: unused_local_variable
    File file = await writeBytes(listBytes);

    fetchResponse(file);

    setState(() {
      imgBytes = pngBytes;
    });
  }

  void loadImage(File file) {
    setState(() {
      img1 = Image.file(file);
    });
  }

  void pickImage() async {
    File file = await FilePicker.getFile();
    loadImage(file);
    fetchResponse(file);
  }

  void fetchResponse(File imageFile) async {
    final mimeTypeData =
        lookupMimeType(imageFile.path, headerBytes: [0xFF, 0xD8]).split('/');
    final imageUploadRequest = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.43.75:5000/generate'));

    final file = await http.MultipartFile.fromPath('image', imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]));

    imageUploadRequest.fields['ext'] = mimeTypeData[1];
    imageUploadRequest.files.add(file);

    try {
      final streamedResponse = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(' * STATUS CODE: ${response.statusCode}');

      final Map<String, dynamic> responseData = json.decode(response.body);
      String outputFile = responseData['result'];

      print('  * OUTPUT FILE: ' + outputFile.toString());
      displayResponseImage(outputFile);
    } catch (e) {
      print('* ERROR: ' + e.toString());
      return null;
    }
  }

  void displayResponseImage(String fileName) async {
    setState(() {
      String outputFile = 'http://192.168.43.75:5000/download/' + fileName;
      imageOutput = Container(
          width: 256,
          height: 256,
          child: CachedNetworkImage(imageUrl: outputFile));
    });
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/test.png');
  }

  Future<File> writeBytes(listBytes) async {
    final file = await _localFile;

    return file.writeAsBytes(listBytes, flush: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            setState(() {
              _loading = true;
            });
          },
          child: Icon(Icons.arrow_back_ios),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                  Color.fromRGBO(138, 35, 135, 1.0),
                  Color.fromRGBO(233, 64, 87, 1.0),
                  Color.fromRGBO(242, 113, 33, 1.0)
                ])),
          ),
          _loading == true
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Container(
                          width: 256,
                          height: 256,
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                    color: Colors.black.withOpacity(0.5))
                              ]),
                          child: GestureDetector(
                            onPanDown: (details) {
                              this.setState(() {
                                points.add(DrawingArea(
                                    point: details.localPosition,
                                    areaPaint: Paint()
                                      ..strokeCap = StrokeCap.round
                                      ..isAntiAlias = true
                                      ..color = Colors.black
                                      ..strokeWidth = 5.0));
                              });
                            },
                            onPanUpdate: (details) {
                              this.setState(() {
                                points.add(DrawingArea(
                                    point: details.localPosition,
                                    areaPaint: Paint()
                                      ..strokeCap = StrokeCap.round
                                      ..isAntiAlias = true
                                      ..color = Colors.black
                                      ..strokeWidth = 5.0));
                              });
                            },
                            onPanEnd: (details) {
                              this.setState(() {
                                {
                                  points.add(null);
                                }
                              });
                            },
                            child: SizedBox.expand(
                              child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                  child: CustomPaint(
                                    painter: MyCustomPainter(points: points),
                                  )),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.save,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                saveToImage(points);
                                _loading = false;
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                pickImage();
                                _loading = false;
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.layers_clear,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                this.setState(() {
                                  points.clear();
                                });
                              },
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                )
              : ListView(
                  children: <Widget>[
                    // img1,
                    Container(
                      width: 256,
                      height: 256,
                      child: img1,
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: Container(
                          height: 256, width: 256, child: imageOutput),
                    ),
                    SizedBox(height: 30),
                    imgBytes != null
                        ? Center(
                            child: Image.memory(
                            Uint8List.view(imgBytes.buffer),
                            width: 256,
                            height: 256,
                          ))
                        : Text('No image saved')
                  ],
                ),
        ],
      ),
    );
  }
}
