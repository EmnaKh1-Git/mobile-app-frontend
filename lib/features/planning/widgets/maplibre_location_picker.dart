import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class MapLibreLocationPicker extends StatefulWidget {
  const MapLibreLocationPicker({super.key});

  @override
  State<MapLibreLocationPicker> createState() => _MapLibreLocationPickerState();
}

class _MapLibreLocationPickerState extends State<MapLibreLocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  MapLibreMapController? _mapController;
  
  LatLng _selectedPoint = const LatLng(34.0, 9.0); // Centre de la Tunisie
  String _address = '';
  bool _isLoading = false;

  // Limites de la Tunisie
  final LatLngBounds _tunisiaBounds = LatLngBounds(
    southwest: const LatLng(30.230, 7.520),
    northeast: const LatLng(37.540, 11.590),
  );

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir au moins 3 caractères.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Recherche ciblée sur la Tunisie
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&countrycodes=tn&limit=1',
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'covoiturage_etudiant/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        if (data.isNotEmpty) {
          final first = data.first;
          final lat = double.parse(first['lat']);
          final lon = double.parse(first['lon']);
          final displayName = first['display_name'] ?? 'Adresse trouvée';
          
          final newPoint = LatLng(lat, lon);
          
          setState(() {
            _selectedPoint = newPoint;
            _address = displayName;
          });

          if (_mapController != null) {
            // 1. On déplace la caméra
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(newPoint, 14), // Zoom 14 pour bien voir la ville
            );
            // 2. On ajoute le marqueur rouge
            _addMarker(newPoint);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun résultat trouvé en Tunisie pour cette recherche.")),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur de connexion.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fonction pour dessiner un marqueur
  void _addMarker(LatLng point) async {
    if (_mapController == null) return;
    
    try {
      // Efface les anciens marqueurs
      await _mapController!.clearSymbols();
      
      // Ajoute le nouveau marqueur
      await _mapController!.addSymbol(
        SymbolOptions(
          geometry: point,
          iconImage: 'marker-15', // Icône par défaut de MapLibre
          iconSize: 1.5,
          iconColor: '#FF0000', // Rouge
        ),
      );
    } catch (e) {
      debugPrint("Erreur marqueur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher (ex: La Marsa, Sousse)...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _searchAddress(_searchController.text),
            ),
          ),
          onSubmitted: _searchAddress,
        ),
        bottom: _isLoading 
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4.0),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: (MapLibreMapController controller) {
              _mapController = controller;
            },
            // ⬇️ LA CARTE DÉTAILLÉE GRATUITE (AVEC LES NOMS) ⬇️
            styleString: 'https://tiles.openfreemap.org/styles/liberty',
            
            initialCameraPosition: CameraPosition(
              target: _selectedPoint,
              zoom: 6.2, // Pour voir toute la Tunisie
            ),
            
            cameraTargetBounds: CameraTargetBounds(_tunisiaBounds),
            minMaxZoomPreference: const MinMaxZoomPreference(5.5, 18.0),
            
            onMapClick: (point, latLng) {
              setState(() {
                _selectedPoint = latLng;
                _address = 'Point sélectionné sur la carte';
              });
              _addMarker(latLng);
            },
          ),
          
          // Optionnel : Afficher l'adresse sélectionnée en bas de l'écran
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Text(
                _address.isEmpty ? "Appuyez sur la carte ou recherchez une adresse" : _address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'lat': _selectedPoint.latitude,
                  'lng': _selectedPoint.longitude,
                  'address': _address.isNotEmpty ? _address : 'Point sélectionné sur la carte',
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Confirmer la destination',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}