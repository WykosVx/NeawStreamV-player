class Canal {
  final String nombre;
  final String url;
  final String logoUrl;

  Canal({
    required this.nombre,
    required this.url,
    this.logoUrl = "",

  });

  factory Canal.fromMap(Map<String, dynamic> data) {
    return Canal(
      nombre: data['nombre'] ?? 'Sin nombre',
      url: data['url'] ?? '',
      logoUrl: data['logo'] ?? '',
    );
  }
}