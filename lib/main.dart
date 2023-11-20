import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk memformat tanggal
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      print("Firebase initialized successfully!");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error initializing Firebase: $e");
    }
  }

  final AuthService authService = AuthService();
  final List<Project> projects = await authService.getProjects(); // Fetch projects from Firebase

  runApp(MyApp(authService: authService, projects: projects));
}

class User {
  final String uid;
  final String email;
  final String displayName;

  User({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  factory User.fromDocument(QueryDocumentSnapshot document) {
    return User(
      uid: document.id,
      email: document['email'] as String,
      displayName: document['name'] as String,
    );
  }
}

class Project {
  final String uid;
  final String author;
  final String title;
  final String description;
  final bool completed;
  final DateTime timestamp; // Tambahkan atribut timestamp

  Project({
    required this.uid,
    required this.author,
    required this.title,
    required this.description,
    required this.completed,
    required this.timestamp, // Tambahkan inisialisasi atribut timestamp pada konstruktor
  });

  factory Project.fromDocument(QueryDocumentSnapshot document) {
    return Project(
      uid: document.id,
      author: document['owner'] as String,
      title: document['title'] as String,
      description: document['description'] as String,
      completed: document['status'] as bool,
      timestamp: (document['created_at'] as Timestamp).toDate(), // Konversi timestamp Firestore menjadi DateTime
    );
  }
}

class Task {
  final String uid;
  final String title;
  final String author;
  final String description;
  final bool completed;
  final DateTime timestamp; // Tambahkan atribut timestamp

  Task({
    required this.uid,
    required this.title,
    required this.author,
    required this.description,
    required this.completed,
    required this.timestamp,
  });

  static Task fromDocument(QueryDocumentSnapshot document) {
    return Task(
      uid: document.id,
      title: document['title'] as String,
      author: document['assignedTo'] as String,
      description: document['description'] as String,
      completed: document['status'] as bool,
      timestamp: (document['created_at'] as Timestamp).toDate(), // Konversi timestamp Firestore menjadi DateTime
    );
  }
}

// Buat model data untuk komentar
class Comment {
  final String username;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.username,
    required this.text,
    required this.timestamp,
  });
}

// Mendapatkan referensi ke koleksi
final CollectionReference projectsCollection =
FirebaseFirestore.instance.collection('projects');

class MyApp extends StatelessWidget {
  final AuthService authService;
  final List<Project> projects;

  const MyApp({
    super.key,
    required this.authService,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: authService.getCurrentUser(),
      builder: (context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          User? user = snapshot.data;
          return MaterialApp(
            title: 'ProjectSync Demo',
            theme: ThemeData(
              primarySwatch: Colors.deepPurple,
            ),
            home: user != null
                ? HomePage(user: user, projects: projects,)
                : LoginPage(authService: authService, projects: projects,),
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> register(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Tambahkan kode untuk menyimpan data user ke Firestore
      await _db.collection('users').doc(result.user!.uid).set({
        'name': name,
        'email': email,
        'password': password
      });

      return User(
        uid: result.user!.uid,
        email: result.user!.email!,
        displayName: result.user!.displayName ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return User(
        uid: result.user!.uid,
        email: result.user!.email!,
        displayName: result.user!.displayName ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<User?> getCurrentUser() async {
    User? user = _auth.currentUser as User?;

    if (user != null) {
      return User(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    } else {
      return null;
    }
  }

  // Implement getProjects method to fetch projects from Firebase
  Future<List<Project>> getProjects() async {
    CollectionReference projectsCollection = _db.collection('projects');
    QuerySnapshot snapshot = await projectsCollection.get();

    List<Project> projects = [];
    for (QueryDocumentSnapshot document in snapshot.docs) {
      projects.add(Project.fromDocument(document));
    }
    return projects;
  }

  // Implement getTasks method to fetch tasks from Firebase
  Future<List<Task>> getTasks(String uid) async {
    CollectionReference tasksCollection = _db.collection('users/$uid/tasks');
    QuerySnapshot snapshot = await tasksCollection.get();

    List<Task> tasks = [];
    for (QueryDocumentSnapshot document in snapshot.docs) {
      tasks.add(Task.fromDocument(document));
    }
    return tasks;
  }
}

class RegisterPage extends StatefulWidget {
  final AuthService authService;
  final List<Project> projects;

  const RegisterPage({
    super.key,
    required this.authService,
    required this.projects,
  });

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'ProjectSync',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Lakukan logika autentikasi dengan AuthService saat tombol login ditekan
                  final email = emailController.text;
                  final password = passwordController.text;
                  final name = nameController.text;

                  widget.authService
                      .register(email, password, name)
                      .then((loggedIn) {
                    if (loggedIn != null) {
                      // Jika register berhasil, arahkan ke HomePage
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(
                            user: loggedIn,
                            projects: widget.projects,
                          ),
                        ),
                      );
                    } else {
                      // Jika register gagal, tampilkan pesan kesalahan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Register gagal. Periksa email dan password Anda.'),
                        ),
                      );
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final AuthService authService;
  final List<Project> projects;

  const LoginPage({
    super.key,
    required this.authService,
    required this.projects,
  });

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'ProjectSync',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController, // Gunakan controller untuk mengakses nilai input
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController, // Gunakan controller untuk mengakses nilai input
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                obscureText: true, // Untuk menyembunyikan teks password
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Lakukan logika login dengan AuthService saat tombol login ditekan
                  final email = emailController.text;
                  final password = passwordController.text;

                  widget.authService.login(email, password).then((loggedIn) {
                    if (loggedIn != null) {
                      User loggedInUser = User(
                        uid: loggedIn.uid,
                        email: loggedIn.email,
                        displayName: loggedIn.displayName,
                      );

                      // Jika login berhasil, arahkan ke halaman HomePage
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(user: loggedInUser, projects: widget.projects,),
                        ),
                      );
                    } else {
                      // Jika login gagal, tampilkan pesan kesalahan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login gagal. Periksa email dan password Anda.'),
                        ),
                      );
                    }
                  });

                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text('Login'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum punya akun?'),
                  TextButton(
                    onPressed: () {
                      // Arahkan ke halaman register
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterPage(authService: AuthService(), projects: widget.projects,),
                        ),
                      );
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<Project> projects;
  final User user;

  const HomePage({super.key, required this.projects, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Project> projects = [];
  List<Project> latestProjects = [];
  List<Project> projectsCreatedByUser = [];

  @override
  void initState() {
    super.initState();

    // Retrieve the latest projects
    FirebaseFirestore.instance
        .collection('projects')
        .where('participants', arrayContains: widget.user.uid)
        .orderBy('timestamp', descending: true) // Mengurutkan berdasarkan timestamp secara descending
        .limit(5)
        .get()
        .then((QuerySnapshot snapshot) {
      setState(() {
        latestProjects =
            snapshot.docs.map((doc) => Project.fromDocument(doc)).toList();
      });
    });


    // Retrieve projects created by the current user
    FirebaseFirestore.instance
        .collection('projects')
        .where('creatorUid', isEqualTo: widget.user.uid)
        .get()
        .then((QuerySnapshot snapshot) {
      setState(() {
        projectsCreatedByUser = snapshot.docs.map((doc) => Project.fromDocument(doc)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const SizedBox(
              height: 250,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage(''), // Ganti dengan foto profil pengguna
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Nama Pengguna',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'pengguna@example.com', // Ganti dengan email pengguna
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: () {
                // Tampilkan dialog peringatan sebelum logout
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Anda yakin ingin logout?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Batal'),
                            onPressed: () {
                            Navigator.of(context).pop(); // Tutup dialog
                            },
                          ),
                          TextButton(
                            child: const Text('Logout'),
                            onPressed: () {
                              // Lakukan logout di sini (bersihkan sesi, dll.)
                              // Setelah logout selesai, arahkan pengguna ke halaman login atau halaman awal aplikasi
                              Navigator.of(context).pop(); // Tutup dialog logout
                              Navigator.pushReplacement(context, MaterialPageRoute(
                                builder: (context) => LoginPage(projects: widget.projects, authService: AuthService()),
                                )
                              );
                            },
                          ),
                        ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: ListView(
        children: [
          _buildCardGroup("Latest Projects", latestProjects), // Changed
          _buildCardGroup("Created by You", projectsCreatedByUser), // Changed
          // ...
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahProyekPage()),
          ).then((newProject) {
            if (newProject != null) {
              setState(() {
                widget.projects.add(newProject);
              });
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardGroup(String groupTitle, List<Project> projectList) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            groupTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height / 3,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: projectList.length,
            itemBuilder: (BuildContext context, int index) {
              if (index < projectList.length) {
                return _buildCard(widget.user, projectList[index]);
              } else {
                return const SizedBox(width: 0, height: 0);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(User user, dynamic document) {
    // Lakukan fetching data dari Firestore atau gunakan reference
    // Tambahkan logika untuk menangani baik proyek maupun tugas
    String title = '';
    String description = '';
    String author = '';

    if (document is Project) {
      title = document.title;
      description = document.description;
      author = document.author;
    } else if (document is Task) {
      title = document.title;
      description = document.description;
      author = document.author;
    }

    return GestureDetector(
      onTap: () {
        // Navigasi ke halaman detail tugas atau proyek dengan judul yang sesuai
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailTugasPage(
              taskTitle: title,
              taskDescription: description,
              // Tambahkan atribut lain yang sesuai seperti kumpulan file dan link
            ),
          ),
        );
      },
      child: Container(
        width: 200, // Lebar kartu
        margin: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 4, // Efek bayangan pada kartu
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Bentuk rounded
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 200, // Lebar gambar (dalam hal ini warna)
                height: 150, // Tinggi gambar (dalam hal ini warna)
                color: Colors.deepPurple, // Ganti dengan warna atau gambar yang sesuai
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                author,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailProyekPage extends StatelessWidget {
  final Project project;

  const DetailProyekPage(this.project, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title), // Menampilkan judul proyek
      ),
      body: Center(
        // Tambahkan daftar tugas di sini
        child: ListView(
          children: [
            // Card tugas 1
          _buildTaskCard("Tugas 1", "Deskripsi Tugas 1", "Teks, File, Link", context),
          // Card tugas 2
          _buildTaskCard("Tugas 2", "Deskripsi Tugas 2", "Teks, File, Link", context),
          // Tambahkan card tugas lainnya sesuai kebutuhan
          ]
        ),
      ),
      floatingActionButton: ElevatedButton(
        onPressed: () {
          // Navigasi ke halaman tambah tugas
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TambahTugasPage(), // Mengirim daftar tugas
            ),
          );
        },
        child: const Text('Tambah Tugas'),
      ),
    );
  }

  Widget _buildTaskCard(String taskTitle, String taskDescription, String taskInfo, BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(taskTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(taskDescription),
            Text(taskInfo),
          ],
        ),
        onTap: () {
          // Tambahkan aksi ketika card tugas di-klik
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailTugasPage(
                taskTitle: taskTitle,
                taskDescription: taskDescription,
                // Tambahkan atribut lain yang sesuai seperti kumpulan file dan link
              ),
            ),
          );
        },
      ),
    );
  }
}

class TambahProyekPage extends StatefulWidget {
  const TambahProyekPage({super.key});

  @override
  _TambahProyekPageState createState() => _TambahProyekPageState();
}

class _TambahProyekPageState extends State<TambahProyekPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final String author = 'Dase';

  final CollectionReference projectsCollection =
  FirebaseFirestore.instance.collection('projects');

  Future<void> _addProject() async {
    if (kDebugMode) {
      print('Adding project: ${titleController.text}, ${descriptionController.text}');
    }

    // Menambahkan proyek baru ke Cloud Firestore
    final newProject = Project(
      title: titleController.text,
      description: descriptionController.text,
      author: author,
      uid: '', // Sesuaikan dengan nilai yang sesuai
      completed: false, // Sesuaikan dengan nilai yang sesuai
      timestamp: DateTime.now(), // Gunakan waktu saat ini sebagai timestamp
    );

    // Kembali ke halaman Beranda dan kirim proyek baru
    Navigator.of(context).pop(newProject);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Proyek Baru'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Proyek',
                ),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Proyek',
                ),
              ),
              ElevatedButton(
                onPressed: _addProject,
                child: const Text('Buat Proyek'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailTugasPage extends StatefulWidget {
  final String taskTitle;
  final String taskDescription;
  final List<String> uploadedFiles;
  final List<String> links;

  const DetailTugasPage({
    super.key,
    required this.taskTitle,
    required this.taskDescription,
    this.uploadedFiles = const [],
    this.links = const [],
  });

  @override
  _DetailTugasPageState createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  List<Comment> comments = [];
  final commentController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    descriptionController.text = widget.taskDescription;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigasi ke halaman edit deskripsi
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditDeskripsiPage(
                    descriptionController: descriptionController,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Bagian Deskripsi
            Text(
              widget.taskDescription,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Bagian Daftar File Terunggah
            _buildFileSection(widget.uploadedFiles),

            // Bagian Daftar Tautan
            _buildLinkSection(widget.links),

            // Tombol untuk membuka halaman komentar terpisah
            ElevatedButton.icon(
              onPressed: () {
                // Navigasi ke halaman komentar
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => KomentarPage(
                      taskTitle: widget.taskTitle,
                      comments: comments,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Komentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection(List<String> uploadedFiles) {
    return uploadedFiles.isEmpty
        ? Container() // Tidak menampilkan sesuatu jika tidak ada file
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar File Terunggah',
          style: TextStyle(fontSize: 18),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: uploadedFiles.length,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(
              title: Text('File ${index + 1}'),
              subtitle: Text(uploadedFiles[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLinkSection(List<String> links) {
    return links.isEmpty
        ? Container() // Tidak menampilkan sesuatu jika tidak ada tautan
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Tautan',
          style: TextStyle(fontSize: 18),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: links.length,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(
              title: Text('Link ${index + 1}'),
              subtitle: Text(links[index]),
            );
          },
        ),
      ],
    );
  }
}

class KomentarPage extends StatefulWidget {
  final String taskTitle;
  final List<Comment> comments;

  const KomentarPage({
    super.key,
    required this.taskTitle,
    required this.comments,
  });

  @override
  _KomentarPageState createState() => _KomentarPageState();
}

class _KomentarPageState extends State<KomentarPage> {
  final commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Komentar - ${widget.taskTitle}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Menampilkan daftar komentar
            Expanded(
              child: ListView.builder(
                itemCount: widget.comments.length,
                itemBuilder: (context, index) {
                  final comment = widget.comments[index];
                  return ListTile(
                    title: Text(comment.username),
                    subtitle: Text(comment.text),
                    trailing: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(comment.timestamp),
                    ),
                    // Menambahkan aksi untuk menghapus komentar
                    onLongPress: () {
                      // Hanya izinkan pengguna yang menambahkan komentar untuk menghapusnya
                      if (comment.username == "Nama Pengguna") {
                        _showDeleteDialog(comment);
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Input komentar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Tambahkan komentar...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    addComment();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void addComment() {
    final text = commentController.text;
    if (text.isNotEmpty) {
      final newComment = Comment(
        username: "Nama Pengguna",
        text: text,
        timestamp: DateTime.now(),
      );
      setState(() {
        widget.comments.add(newComment);
        commentController.clear();
      });
    }
  }

  void _showDeleteDialog(Comment comment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Komentar'),
          content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
              },
            ),
            TextButton(
              child: const Text('Hapus'),
              onPressed: () {
                // Hapus komentar dari daftar
                setState(() {
                  widget.comments.remove(comment);
                });
                Navigator.of(context).pop(); // Tutup dialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }
}

class TambahTugasPage extends StatefulWidget {
  const TambahTugasPage({super.key});

  @override
  _TambahTugasPageState createState() => _TambahTugasPageState();
}

class _TambahTugasPageState extends State<TambahTugasPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final String author = 'Dase';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Tugas Baru'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Tugas',
                ),
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Tugas',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (kDebugMode) {
                    print('Adding task: ${titleController.text}, ${descriptionController.text}');
                  }
                  // Membuat tugas baru
                  final newTask = Task(
                    uid: '',
                    title: titleController.text,
                    description: descriptionController.text,
                    author: author,
                    completed: false,
                    timestamp: DateTime.now(), // Contoh pembuatan referensi dokumen kosong
                  );

                  // Kembali ke halaman DetailProyekPage dan kirim tugas baru
                  Navigator.of(context).pop(newTask);
                },
                child: const Text('Buat Tugas'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditDeskripsiPage extends StatefulWidget {
  final TextEditingController descriptionController;

  const EditDeskripsiPage({super.key, required this.descriptionController});

  @override
  _EditDeskripsiPageState createState() => _EditDeskripsiPageState();
}

class _EditDeskripsiPageState extends State<EditDeskripsiPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Deskripsi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: widget.descriptionController,
              maxLines: null, // Ini akan membuatnya teks panjang
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
