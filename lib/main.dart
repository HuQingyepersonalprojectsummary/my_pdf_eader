import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  Color _backgroundColor;

  ThemeProvider() : _backgroundColor = Colors.grey[100]!;

  Color get backgroundColor => _backgroundColor;

  void setNightMode() {
    _backgroundColor = Colors.yellow[100]!;
    notifyListeners();
  }

  void setDayMode() {
    _backgroundColor = Colors.grey[100]!;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          home: DirectoryPage(),
          theme: ThemeData(
            scaffoldBackgroundColor: themeProvider.backgroundColor,
          ),
        );
      },
    );
  }
}

class DirectoryPage extends StatefulWidget {
  @override
  _DirectoryPageState createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  List<String> pdfFilePaths = [];
  bool showSearchBar = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPdfFilePaths();
  }

  Future<String> getDirectoryPath() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  Future<void> importPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      String directoryPath = await getDirectoryPath();
      File file = File(result.files.single.path!);
      String newFileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      File newFile = await file.copy('$directoryPath/$newFileName');
      setState(() {
        pdfFilePaths.add(newFile.path);
        _savePdfFilePaths();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件已保存到：$directoryPath'),
            duration: Duration(seconds: 9),
          ),
        );
      });
    }
  }

  void clearAllPdfs() {
    setState(() {
      for (var filePath in pdfFilePaths) {
        File(filePath).deleteSync();
      }
      pdfFilePaths.clear();
      _savePdfFilePaths();
    });
  }

  void deletePdf(String filePath) {
    setState(() {
      File(filePath).deleteSync();
      pdfFilePaths.remove(filePath);
      _savePdfFilePaths();
    });
  }

  Future<void> _loadPdfFilePaths() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      pdfFilePaths = prefs.getStringList('pdfFilePaths') ?? [];
    });
  }

  Future<void> _savePdfFilePaths() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFilePaths', pdfFilePaths);
  }

  List<String> searchResults() {
    String query = searchController.text;
    if (query.length < 2) {
      return pdfFilePaths;
    }
    return pdfFilePaths.where((path) => path.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('电子书目录'),
        backgroundColor: Colors.grey[100],
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                showSearchBar = !showSearchBar;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: clearAllPdfs,
          ),
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: importPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          if (showSearchBar)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: '搜索文件名',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults().length,
              itemBuilder: (context, index) {
                String filePath = searchResults()[index];
                return ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: _highlightMatchedText(filePath.split('/').last),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PDFViewerPage(filePath: filePath),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => deletePdf(filePath),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu, color: Colors.lightGreen),
            label: '目录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Colors.lightGreen),
            label: '设置',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsPage()),
            );
          }
        },
      ),
    );
  }

  Widget _highlightMatchedText(String text) {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty || query.length < 2) {
      return Text(text);
    }

    List<TextSpan> spans = [];
    int start = 0;
    int index;
    text = text.toLowerCase();
    while ((index = text.indexOf(query, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(backgroundColor: Colors.red),
      ));
      start = index + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return RichText(text: TextSpan(children: spans, style: TextStyle(color: Colors.black)));
  }
}

class PDFViewerPage extends StatefulWidget {
  final String filePath;

  PDFViewerPage({required this.filePath});

  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  late PdfViewerController _pdfViewerController;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadLastPage();
  }

  Future<void> _loadLastPage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int lastPage = prefs.getInt('${widget.filePath}_lastPage') ?? 1;
    _pdfViewerController.jumpToPage(lastPage);
    setState(() {
      _currentPage = lastPage;
      _isLoaded = true;
    });
  }

  Future<void> _saveLastPage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${widget.filePath}_lastPage', _currentPage);
  }

  @override
  void dispose() {
    _saveLastPage();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_upward),
            onPressed: () {
              _pdfViewerController.jumpToPage(1);
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward),
            onPressed: () {
              _pdfViewerController.jumpToPage(_totalPages);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoaded)
            Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: SfPdfViewer.file(
                File(widget.filePath),
                controller: _pdfViewerController,
                onDocumentLoaded: (details) {
                  setState(() {
                    _totalPages = details.document.pages.count;
                  });
                },
                onPageChanged: (details) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                },
                canShowScrollHead: true,
                canShowScrollStatus: true,
                pageSpacing: 5.0,
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page $_currentPage of $_totalPages'),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_upward),
                      onPressed: () {
                        _pdfViewerController.previousPage();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_downward),
                      onPressed: () {
                        _pdfViewerController.nextPage();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('通用设置'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GeneralSettingsPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('软件版本'),
          ),
          ListTile(
            leading: Icon(Icons.help),
            title: Text('软件帮助'),
          ),
          ListTile(
            leading: Icon(Icons.description),
            title: Text('软件说明'),
          ),
          ListTile(
            leading: Icon(Icons.contact_mail),
            title: Text('联系开发者'),
          ),
        ],
      ),
    );
  }
}

class GeneralSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通用设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.backup),
            title: Text('备份功能'),
            // 添加备份功能
          ),
          ListTile(
            leading: Icon(Icons.color_lens),
            title: Text('更换背景'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChangeBackgroundPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ChangeBackgroundPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('更换背景'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('白天模式'),
            onTap: () {
              Provider.of<ThemeProvider>(context, listen: false).setDayMode();
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('夜晚模式'),
            onTap: () {
              Provider.of<ThemeProvider>(context, listen: false).setNightMode();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
