import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_action_screen.dart';
import '../models/player.dart';

void main() {
  runApp(const MaterialApp(home: CreateMatchScreen()));
}

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final TextEditingController _matchNameController = TextEditingController();
  final TextEditingController _teamAController = TextEditingController();
  final TextEditingController _teamBController = TextEditingController();

  static const int maxPlayers = 11; // Maximum players per team
  final List<Player> _teamAPlayers = [];
  final List<Player> _teamBPlayers = [];
  final Set<String> _existingMatches = {};
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadExistingMatches();
  }

  Future<void> _loadExistingMatches() async {
    try {
      // Clear existing matches first
      setState(() {
        _existingMatches.clear();
      });

      // Only get matches that were actually started or completed
      final matchesSnapshot =
          await _db
              .collection('matches')
              .where('status', whereIn: ['started', 'completed'])
              .get();

      setState(() {
        for (final doc in matchesSnapshot.docs) {
          final matchName = doc.data()['matchName'] as String? ?? '';
          _existingMatches.add(matchName);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading matches: $e')));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _addPlayer(List<Player> teamList) async {
    if (teamList.length >= maxPlayers) {
      _showError("Maximum number of players (11) reached for this team.");
      return;
    }

    String name = '';
    String number = '';
    XFile? pickedImage;
    String? base64Image;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Player'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Number'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => number = value,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    pickedImage = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedImage != null) {
                      final bytes = await File(pickedImage!.path).readAsBytes();
                      base64Image = base64Encode(bytes);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Image selected')),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Select Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (name.isNotEmpty && number.isNotEmpty) {
                    setState(() {
                      teamList.add(
                        Player(
                          id:
                              name.toLowerCase().replaceAll(' ', '_') +
                              '_' +
                              number,
                          name: name,
                          number: number,
                          imageBase64: base64Image,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  } else {
                    _showError("Player name and number are required.");
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _editPlayer(List<Player> teamList, int index) async {
    Player currentPlayer = teamList[index];
    String name = currentPlayer.name;
    String number = currentPlayer.number;
    String? base64Image = currentPlayer.imageBase64;
    XFile? pickedImage;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Player'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  controller: TextEditingController(text: name),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Number'),
                  controller: TextEditingController(text: number),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => number = value,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    pickedImage = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedImage != null) {
                      final bytes = await File(pickedImage!.path).readAsBytes();
                      base64Image = base64Encode(bytes);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New image selected')),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Change Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (name.isNotEmpty && number.isNotEmpty) {
                    setState(() {
                      teamList[index] = Player(
                        id:
                            name.toLowerCase().replaceAll(' ', '_') +
                            '_' +
                            number,
                        name: name,
                        number: number,
                        imageBase64: base64Image,
                      );
                    });
                    Navigator.pop(context);
                  } else {
                    _showError("Player name and number are required.");
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _startMatch() async {
    final matchName = _matchNameController.text.trim();
    final teamAName = _teamAController.text.trim();
    final teamBName = _teamBController.text.trim();

    if (matchName.isEmpty || teamAName.isEmpty || teamBName.isEmpty) {
      _showError("All names must be filled.");
      return;
    }

    if (teamAName == teamBName) {
      _showError("Teams must have different names.");
      return;
    }

    print('Checking if match exists: $matchName');
    print('Existing matches: ${_existingMatches.toString()}');

    // Check only against started matches
    if (_existingMatches.contains(matchName)) {
      _showError("Match name already exists.");
      return;
    }

    if (_teamAPlayers.length < 2 || _teamBPlayers.length < 2) {
      _showError("Each team must have at least 2 players.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create match document
      final matchRef = _db.collection('matches').doc();
      final matchId = matchRef.id;

      print('Creating new match with ID: $matchId and name: $matchName');

      // Create batch operation
      final batch = _db.batch();

      // Set match document with initial status
      batch.set(matchRef, {
        'matchName': matchName,
        'teamA': teamAName,
        'teamB': teamBName,
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'isActive': false,
        'finalScore': '0 : 0',
        '${teamAName}_score': 0,
        '${teamBName}_score': 0,
        'status': 'created', // Initial status
      });

      // Add team A players
      for (final player in _teamAPlayers) {
        final playerRef = matchRef.collection(teamAName).doc(player.id);
        batch.set(playerRef, {
          'name': player.name,
          'number': player.number,
          'imageBase64': player.imageBase64,
          'stats': {
            'goals': 0,
            'behinds': 0,
            'kicks': 0,
            'handballs': 0,
            'marks': 0,
            'tackles': 0,
          },
        });
      }

      // Add team B players
      for (final player in _teamBPlayers) {
        final playerRef = matchRef.collection(teamBName).doc(player.id);
        batch.set(playerRef, {
          'name': player.name,
          'number': player.number,
          'imageBase64': player.imageBase64,
          'stats': {
            'goals': 0,
            'behinds': 0,
            'kicks': 0,
            'handballs': 0,
            'marks': 0,
            'tackles': 0,
          },
        });
      }

      // Commit all changes
      await batch.commit();

      setState(() => _existingMatches.add(matchName));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MatchActionScreen(
                matchId: matchId,
                teamA: teamAName,
                teamB: teamBName,
                matchName: matchName,
                teamAPlayers: _teamAPlayers,
                teamBPlayers: _teamBPlayers,
              ),
        ),
      );
    } catch (e) {
      _showError("Error creating match: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamSection(
    String title,
    List<Player> players,
    VoidCallback onAddPlayer,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller:
                  title == "Team A" ? _teamAController : _teamBController,
              decoration: InputDecoration(
                labelText: "$title Name",
                labelStyle: TextStyle(color: Colors.blue[900]),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade900),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAddPlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Player to $title'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Players:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No players added yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: players.length,
                itemBuilder:
                    (context, index) => ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            players[index].imageBase64 != null
                                ? MemoryImage(
                                  base64Decode(players[index].imageBase64!),
                                )
                                : null,
                        child:
                            players[index].imageBase64 == null
                                ? const Icon(Icons.person)
                                : null,
                      ),
                      title: Text(players[index].name),
                      subtitle: Text('Number: ${players[index].number}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editPlayer(players, index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () => setState(() => players.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Match'),
        backgroundColor: Colors.red[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed:
              () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.red[900]!, Colors.grey[200]!],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Card(
                        margin: const EdgeInsets.all(16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _matchNameController,
                            decoration: InputDecoration(
                              labelText: 'Match Name',
                              labelStyle: TextStyle(color: Colors.red[900]),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red.shade200,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildTeamSection(
                        'Team A',
                        _teamAPlayers,
                        () => _addPlayer(_teamAPlayers),
                      ),
                      _buildTeamSection(
                        'Team B',
                        _teamBPlayers,
                        () => _addPlayer(_teamBPlayers),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                          onPressed: _startMatch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow),
                              SizedBox(width: 8),
                              Text(
                                'Start Match',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
