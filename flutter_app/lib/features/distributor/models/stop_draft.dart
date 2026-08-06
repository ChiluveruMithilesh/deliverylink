class StopDraft {
  StopDraft({
    required this.shopName,
    required this.contactNumber,
    required this.lat,
    required this.lng,
    required this.quantity,
    required this.unitType,
    this.shopId,
    this.notes,
  });

  final String? shopId;
  final String shopName;
  final String contactNumber;
  final double lat;
  final double lng;
  final int quantity;
  final String unitType; // cartons | bags | boxes
  final String? notes;

  Map<String, dynamic> toJson() => {
        if (shopId != null) 'shopId': shopId,
        'shopName': shopName,
        'contactNumber': contactNumber,
        'lat': lat,
        'lng': lng,
        'quantity': quantity,
        'unitType': unitType,
        if (notes != null) 'notes': notes,
      };
}
