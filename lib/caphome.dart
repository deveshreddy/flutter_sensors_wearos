import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:isolate';
import 'manfiles.dart';
import 'package:csv/csv.dart';
import 'dart:convert' show utf8;
import 'package:screen/screen.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class capturehome extends StatefulWidget {
  @override
  _capturehomeState createState() => _capturehomeState();
}

class _capturehomeState extends State<capturehome> {
  Isolate isolate;

  //Variables to initialize
  Color capColor = Colors.deepOrangeAccent;
  Color backColor = Colors.white60;

  List<double> _accelerometerValues;
  List<double> _userAccelerometerValues;

  List<List<dynamic>> accelList = List<List<dynamic>>();
  List<List<dynamic>> userAccelList = List<List<dynamic>>();

  List<List<dynamic>> meanAccelList = List<List<dynamic>>();
  List<List<dynamic>> meanUserAccelList = List<List<dynamic>>();

  List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];

  // This widget is the root of your application.

  File file;
  var sink;
  String pathOfTheFileToWrite;

  @override
  Widget build(BuildContext context) {
    return (Scaffold(
      backgroundColor: backColor,
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(15, 200, 250, 0.8),
        title: Text(
          'Sensors Data',
          style: TextStyle(
              color: Colors.black.withOpacity(0.8),
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'BadScript'),
        ),
        centerTitle: true,
      ),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Row(
              //crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Container(
                  child: Text(
                    'Capture',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  padding: EdgeInsets.fromLTRB(3, 20, 3, 20),
                  color: capColor,
                ),
                Container(
                  child: FloatingActionButton(
                    heroTag: "start",
                    onPressed: () {
                      setState(() {
                        backColor = Colors.greenAccent;
                        capColor = Colors.green;
                        //createNewIsolate();
                        Screen.setBrightness(0.1);
                        Screen.keepOn(true);
                        //Wakelock.enable();
                        beginInitState();
                      });
                    },
                    child: Text('Start'),
                  ),
                ),
                Container(
                  child: FloatingActionButton(
                    heroTag: "stop",
                    onPressed: () {
                      setState(() {
                        backColor = Colors.deepOrangeAccent;
                        capColor = Colors.red;
                        //     Read();
                        quit();
                        //dispose();
                      });
                    },
                    child: Text('Stop'),
                  ),
                ),
              ],
            ),
            //Display the text here

            Container(
              child: RaisedButton(
                child: Text("Files"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => manfiles()),
                  );
                },
              ),
            ),

            if (_userAccelerometerValues != null)
              Text(
                  "accel: x: ${_userAccelerometerValues.map((e) => e.toInt()).toList()}"),
          ]),
    )); //return
  } //build

  List<double> calcMean(List<List<dynamic>> findMean) {
    var x = findMean.map((element) => element[0]).toList();
    var y = findMean.map((element) => element[1]).toList();
    var z = findMean.map((element) => element[2]).toList();

    double xval = x.reduce((curr, next) => curr + next) / x.length;
    double yval = y.reduce((curr, next) => curr + next) / y.length;
    double zval = z.reduce((curr, next) => curr + next) / z.length;

    List<double> meanVal = [xval, yval, zval];
    print(meanVal);
    return (meanVal);
  }

  @override
  void quit() {
    //super.dispose();
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  double getEuc(xyz) {
    double res = pow(xyz[0], 2) + pow(xyz[1], 2) + pow(xyz[2], 2);
    res = sqrt(res);
    return (res);
  }

  void beginInitState() {
    int ucount = 0;
    int uuploadCount = 0;

    this
        ._streamSubscriptions
        .add(userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      setState(() {
        this._userAccelerometerValues = <double>[event.x, event.y, event.z];

        meanUserAccelList.add(_userAccelerometerValues);
        ucount = ucount + 1;

        if (ucount == 5) {
          List<double> meanUserVal = calcMean(meanUserAccelList);
          //add time and resultant acceleration to the meanUserVal list
          meanUserVal.add(getEuc(meanUserVal));
          meanUserVal.insert(0, getTime());

          userAccelList.add(meanUserVal);

          uuploadCount = uuploadCount + 1;
          print(uuploadCount);
          ucount = 0;
          meanUserAccelList = List<List<dynamic>>();
        }

        if (uuploadCount == 1000) {
          Write(userAccelList, "_user_accel");
          userAccelList = List<List<dynamic>>();
          uuploadCount = 0;
        }
      });
    }));
  }

  double getTime() {
    return (DateTime.now().millisecondsSinceEpoch.toDouble());
  }

  Future<String> get localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return (dir.path);
  }

//values, type

  Future Write(values, type) async {
    List<List<dynamic>> toStore = new List<List<dynamic>>();
    // Initial a csv file and push this on top of that
    //toStore.add(values);
    toStore = values;
    //final directory =  await localPath;
    String directory = "/data/user/0/com.example.sensewear/app_flutter/csvdata/";
    String filename = DateTime.now().toString();
    filename = filename + type;
    filename = filename + ".csv";
    final pathOfTheFileToWrite = directory + filename;
    //  print(pathOfTheFileToWrite);
    File file = File(pathOfTheFileToWrite);
    String csv = const ListToCsvConverter().convert(toStore);
    await file.writeAsString(csv);
    await uploadFile(pathOfTheFileToWrite, file);
    return(file);
  }

  Future uploadFile(fileName, csvFile) async {
    final StorageReference reference =
        await FirebaseStorage.instance.ref().child(fileName);
    final StorageUploadTask uploadTask = await reference.putFile(csvFile);
    // StorageTaskSnapshot taskSnapshot = await uploadTask.onComplete;
    // setState(() {
    //   print("Upload complete for the file $fileName");
    // });
    return uploadTask;
  }
} //class
