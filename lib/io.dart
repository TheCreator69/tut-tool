// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/theme_map.dart';
import 'package:file_picker/file_picker.dart';

const textFiles = [".hs", ".txt", ".s", ".asm", ".py"];
const langMap = {
  ".hs": "Haskell",
  ".txt": "Plaintext",
  ".s": "avrasm",
  ".asm": "avrasm",
  ".py": "Python"
};

/// A Widget to display a file
class FileShower extends StatelessWidget {
  final File file;
  const FileShower(this.file, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(file.path);
    if (ext == ".pdf") {
      return const Text("PDF is in the working");
      return Container(
        constraints: const BoxConstraints(maxHeight: 1500),
        child: pdfx.PdfView(
          controller: pdfx.PdfController(
              document: pdfx.PdfDocument.openFile(file.path)),
        ),
      );
    } else if (textFiles.contains(ext)) {
      return FutureBuilder(
          future: file.readAsString(),
          builder: ((context, snapshot) => snapshot.hasData
              ? HighlightView(
                  snapshot.data!,
                  language: langMap[ext],
                  theme: themeMap["github"]!,
                  padding: const EdgeInsets.all(12),
                  textStyle: const TextStyle(
                      fontFamily:
                          'MonoLisa,SFMono-Regular,Consolas,Liberation Mono,Menlo,monospace'),
                )
              : const Text("Loading...")));
    } else {
      return const Text("Unknown File Format");
    }
  }
}

/// A Directory Input
/// It uses a read-only TextField but opens a file picker on tap
class DirInput extends StatelessWidget {
  DirInput({Key? key}) : super(key: key);

  final controller = TextEditingController();

  /// Must only be read when validated!
  Directory get value => Directory(controller.text).absolute;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: const InputDecoration(hintText: "Choose Directory"),
      validator: (text) => text!.isEmpty
          ? "Choose a directory"
          : (value.existsSync() ? null : "Directory doesn't exist"),
      onTap: () async {
        final selectedDir = await FilePicker.platform
            .getDirectoryPath(dialogTitle: "Select your project directory");
        if (selectedDir != null) {
          controller.text = selectedDir;
        }
      },
    );
  }
}

void openFile(File file) {
  try {
    if (Platform.isWindows) {
      Process.run("explorer", [file.absolute.path]);
    } else if (Platform.isLinux || Platform.isMacOS) {
      Process.start("xdg-open", [file.absolute.path]);
    } else {
      throw Exception();
    }
  } catch (e) {
    Get.snackbar(
        "Can't open file", "Not supported on ${Platform.operatingSystem}");
  }
}

void openDir(File file) {
  try {
    if (Platform.isWindows) {
      Process.run("explorer", [p.dirname(file.absolute.path)]);
    } else if (Platform.isLinux || Platform.isMacOS) {
      Process.start("xdg-open", [p.dirname(file.absolute.path)]);
    } else {
      throw Exception();
    }
  } catch (e) {
    Get.snackbar(
        "Can't open directory", "Not supported on ${Platform.operatingSystem}");
  }
}

void consoleDir(File file) {
  try {
    if (Platform.isWindows) {
      Process.run("start", ["cmd"],
          runInShell: true, workingDirectory: p.dirname(file.absolute.path));
    } else if (Platform.isLinux || Platform.isMacOS) {
      Process.start("x-terminal-emulator", [],
          workingDirectory: p.dirname(file.absolute.path));
    } else {
      throw Exception();
    }
  } catch (e) {
    Get.snackbar(
        "Can't open console", "Not supported on ${Platform.operatingSystem}");
  }
}

/// Runs/Starts a file
void runFile(File file) {
  final path = file.path;
  final ext = p.extension(path);
  try {
    if (Platform.isWindows) {
      if (ext == ".hs") {
        Process.run("start", ["cmd", "/c", "ghci", p.basename(path)],
            runInShell: true, workingDirectory: p.dirname(path));
      } else if (ext == ".txt") {
        Process.run("notepad", [file.absolute.path]);
      }
      return;
    } else if (Platform.isLinux || Platform.isMacOS) {
      if (ext == ".hs") {
        Process.start("x-terminal-emulator", ["-e", 'ghci "$path"']);
      } else {
        openFile(file);
      }
      return;
    }
  } catch (e) {}
  Get.snackbar(
      "Can't run file", "Not supported on ${Platform.operatingSystem}");
}

/// Converts file2Text
Future<String> file2Text(File file) async {
  // TODO: unpack zip files
  final ext = p.extension(file.path);
  if (textFiles.contains(ext)) {
    return await file.readAsString();
  } else if (ext == ".pdf") {
    try {
      final document = pdf.PdfDocument(inputBytes: await file.readAsBytes());
      String text = pdf.PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      log("Couldn't extract from PDF: ${file.path}");
    }
  }
  return "";
}

final zipEncoder = ZipFileEncoder();

zipDir(Directory dir) async {
  final resultPath = '${dir.path}.zip';
  await compute(
      (_) async => zipEncoder.zipDirectory(dir, filename: resultPath), 0);
  return File(resultPath);
}

dynamic parseDynamic(String word) {
  word = word.replaceAll('"', "").trim();
  return int.tryParse(word) ?? double.tryParse(word) ?? word;
}

List<List<dynamic>> loadCSV(String text) => [
      for (final line in text.split("\n"))
        [for (final field in line.trim().split(",")) parseDynamic(field)]
    ];

String storeCSV(List<List<dynamic>> table) => [
      for (final line in table) [for (final field in line) '"$field"'].join(",")
    ].join("\n");

//TODO: direct modification in csv tables
