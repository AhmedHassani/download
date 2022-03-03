import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:android_path_provider/android_path_provider.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


class DownloadController extends GetxController{
  List<TaskInfo>? tasksInfo;
  static const debug = true;
  late List<ItemHolder> items=[];
  late bool isLoading;
  late bool permissionReady=false;
  late String localPath;



  List _videos = [
  ];
  ReceivePort port = ReceivePort();

  @override
  Future<void> onInit() async {
    bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    isLoading = false;
    //prepare();
  }

  void bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      unbindBackgroundIsolate();
      bindBackgroundIsolate();
      return;
    }
    port.listen((dynamic data) {
      if (debug) {
        print('UI Isolate Callback: $data');
      }
      String? id = data[0];
      DownloadTaskStatus? status = data[1];
      int? progress = data[2];
      if (tasksInfo != null && tasksInfo!.isNotEmpty) {
        final task = tasksInfo!.firstWhere((task) => task.taskId == id);
          task.status = status;
          task.progress = progress;
      }
    });
  }

  void unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

   static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    if(debug) {
      print('($id) is in status ($status) and process ($progress)');
    }
    final SendPort send =IsolateNameServer.lookupPortByName('downloader_send_port')!;

    send.send([id, status, progress]);
  }


  Future<void> retryRequestPermission() async {
    final hasGranted = await checkPermission();
    if (hasGranted) {
      await prepareSaveDir();
    }
    permissionReady = hasGranted;
    print("hasGranted : $permissionReady");
    update();
  }

  void requestDownload(TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
      url: task.link!,
      headers: {"auth": "test_for_sql_encoding"},
      savedDir: localPath,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );
    update();
  }

  void cancelDownload(TaskInfo task) async {
    await FlutterDownloader.cancel(taskId: task.taskId!);
    update();
  }

  void pauseDownload(TaskInfo task) async {
    await FlutterDownloader.pause(taskId: task.taskId!);
    update();
  }

  void resumeDownload(TaskInfo task) async {
    String? newTaskId = await FlutterDownloader.resume(taskId: task.taskId!);
    task.taskId = newTaskId;
    update();
  }

  void retryDownload(TaskInfo task) async {
    String? newTaskId = await FlutterDownloader.retry(taskId: task.taskId!);
    task.taskId = newTaskId;
    update();
  }

  Future<bool> openDownloadedFile(TaskInfo? task) {
    if (task != null) {
      return FlutterDownloader.open(taskId: task.taskId!);
    } else {
      return Future.value(false);
    }
  }


  void delete(TaskInfo task) async {
    await FlutterDownloader.remove(
        taskId: task.taskId!, shouldDeleteContent: true);
    await prepare();
    update();
  }

  Future<bool> checkPermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (GetPlatform.isAndroid && androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  Future<Null> addTask(String name, String link) async {
    final tasks = await FlutterDownloader.loadTasks();
    int count = 0;
    tasksInfo = [];
    TaskInfo task = TaskInfo(name: name, link: link);
    requestDownload(task);
    tasksInfo!.add(task);
    for (int i = count; i < tasksInfo!.length; i++) {
      items.add(ItemHolder(name: tasksInfo![i].name, task: tasksInfo![i]));
      count++;
    }
    tasks!.forEach((task) {
      for (TaskInfo info in tasksInfo!) {
        if (info.link == task.url) {
          info.taskId = task.taskId;
          info.status = task.status;
          info.progress = task.progress;
        }
      }
    });
    permissionReady = await checkPermission();
    if (permissionReady) {
      await prepareSaveDir();
    }
    isLoading = false;
    update();

  }

  Future<Null> prepare() async {
    final tasks = await FlutterDownloader.loadTasks();
    int count = 0;
    tasksInfo = [];
    tasksInfo!.addAll(_videos.map((video) => TaskInfo(name: video['name'], link: video['link'])));
    for (int i = count; i < tasksInfo!.length; i++) {
      items.add(ItemHolder(name: tasksInfo![i].name, task: tasksInfo![i]));
      count++;
    }

    tasks!.forEach((task) {
      for (TaskInfo info in tasksInfo!) {
        if (info.link == task.url) {
          info.taskId = task.taskId;
          info.status = task.status;
          info.progress = task.progress;
        }
      }
    });

    isLoading = false;
    update();
  }

  Future<void> prepareSaveDir() async {
    localPath = (await findLocalPath())!;
    final savedDir = Directory(localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
    update();
  }

  Future<String?> findLocalPath() async {
    var externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

}


//models
class TaskInfo {
  final String? name;
  final String? link;

  String? taskId;
  int? progress = 0;
  DownloadTaskStatus? status = DownloadTaskStatus.undefined;

  TaskInfo({this.name, this.link});
}

class ItemHolder {
  final String? name;
  final TaskInfo? task;

  ItemHolder({this.name, this.task});
}



/*
     {
      'name': 'Big Buck Bunny',
      'link': 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
    },
    {
      'name': 'Elephant Dream',
      'link':
      'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'
    }
 */