import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';

import 'download_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  late DownloadController _controller;
  @override
  void initState() {
    _controller = Get.put(DownloadController());
    _controller.retryRequestPermission();
    print("permission : ${_controller.permissionReady}");
  }

  void _incrementCounter() {
     _controller.addTask(
         "task$_counter",
         'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'
     );
     _counter=_counter+1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body:GetBuilder(
        init: _controller,
        builder: (GetxController controller) {
             print("permissionReady : ${_controller.permissionReady}");
             if(_controller.permissionReady){
               return _controller.items.length==0 ?notItem():ListView.separated(
                 itemCount: _controller.items.length,
                 itemBuilder: (BuildContext context, int index) {
                   return load(_controller.items[index].task);
                 },
                 separatorBuilder: (BuildContext context, int index) {
                   return const Divider();
                 },
               );
             }else{
                return Center(
                  child:Column(
                    mainAxisAlignment:MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                    ],
                  ),
                );
             }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

   load(TaskInfo  ?item){
    return Container(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: InkWell(
        onTap:() {
        },
        child: Stack(
          children: <Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              height: 64.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children:  [
                  Expanded(
                    child: Text(
                      "${item!.name}",
                      maxLines: 1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),Positioned(
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              child: loadingView(item),
            )]
        )
      ),
    );
   }

    loadingView(TaskInfo ?task) {

      return Column(
        crossAxisAlignment:CrossAxisAlignment.end,
        children:  [
          LinearProgressIndicator(
            value: task!.progress! / 100,
          ),
          Text("${task.progress} / 100")
        ],
      );
  }

  notItem() {
    return Center(
      child:Column(
        mainAxisAlignment:MainAxisAlignment.center,
        children: const [
          Text("item not found"),
        ],
      ),
    );
  }

}
