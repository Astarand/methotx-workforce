class CompanyDetailsModel {
  final String? id;
  final String? compLogo;
  final String? gstReg;
  final String? gstNo;
  final String compName;
  final String? compEmail;
  final String? compPhone;
  final String? compPanNo;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? pin;

  const CompanyDetailsModel({
    this.id,
    this.compLogo,
    this.gstReg,
    this.gstNo,
    required this.compName,
    this.compEmail,
    this.compPhone,
    this.compPanNo,
    this.addressLine1,
    this.city,
    this.state,
    this.pin,
  });

  String get fullAddress {
    final parts = [
      if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
        addressLine1!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (pin != null && pin!.trim().isNotEmpty) pin!.trim(),
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'Registered Corporate Office';
  }

  factory CompanyDetailsModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is List &&
        (json['data'] as List).isNotEmpty &&
        (json['data'] as List).first is Map) {
      data = Map<String, dynamic>.from((json['data'] as List).first as Map);
    } else if (json['company'] is Map<String, dynamic>) {
      data = json['company'] as Map<String, dynamic>;
    } else if (json['company_info'] is Map<String, dynamic>) {
      data = json['company_info'] as Map<String, dynamic>;
    }

    if (data['company_info'] is Map<String, dynamic>) {
      data = data['company_info'] as Map<String, dynamic>;
    } else if (data['company'] is Map<String, dynamic>) {
      data = data['company'] as Map<String, dynamic>;
    }

    String? parseLogo(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      return (str.isEmpty || str == 'null') ? null : str;
    }

    final companyId = data['id']?.toString() ??
        data['comp_id']?.toString() ??
        data['company_id']?.toString() ??
        json['id']?.toString() ??
        json['comp_id']?.toString() ??
        json['company_id']?.toString();

    final logo = parseLogo(data['comp_logo']) ??
        parseLogo(data['compLogo']) ??
        parseLogo(data['logo']) ??
        parseLogo(data['company_logo']) ??
        parseLogo(data['companyLogo']) ??
        parseLogo(json['comp_logo']) ??
        parseLogo(json['logo']);

    return CompanyDetailsModel(
      id: companyId != null &&
              companyId.trim().isNotEmpty &&
              companyId != 'null'
          ? companyId.trim()
          : null,
      compLogo: logo,
      gstReg: data['gst_reg']?.toString() ?? data['gstReg']?.toString(),
      gstNo: data['comp_bill_gst_no']?.toString() ??
          data['gst_no']?.toString() ??
          data['gstNo']?.toString() ??
          data['gstin']?.toString(),
      compName: data['comp_name']?.toString() ??
          data['compName']?.toString() ??
          data['company_name']?.toString() ??
          data['name']?.toString() ??
          'MethotX Workforce',
      compEmail: data['comp_email']?.toString() ??
          data['compEmail']?.toString() ??
          data['email']?.toString(),
      compPhone: data['comp_phone']?.toString() ??
          data['compPhone']?.toString() ??
          data['phone']?.toString(),
      compPanNo: data['comp_pan_no']?.toString() ??
          data['compPanNo']?.toString() ??
          data['pan']?.toString(),
      addressLine1: () {
        final parts = [
          data['comp_bill_addone']?.toString(),
          data['comp_bill_addtwo']?.toString(),
          data['comp_address']?.toString(),
          data['address']?.toString(),
          data['addressLine1']?.toString(),
        ]
            .where((s) => s != null && s.trim().isNotEmpty)
            .map((s) => s!.trim())
            .toList();
        return parts.isNotEmpty ? parts.join(', ') : 'Corporate Office';
      }(),
      city: data['comp_bill_city']?.toString() ?? data['city']?.toString(),
      state: data['comp_bill_state']?.toString() ?? data['state']?.toString(),
      pin: data['comp_bill_pin']?.toString() ??
          data['pin']?.toString() ??
          data['pincode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comp_id': id,
      'company_id': id,
      'comp_logo': compLogo,
      'logo': compLogo,
      'gst_reg': gstReg,
      'gst_no': gstNo,
      'comp_name': compName,
      'comp_email': compEmail,
      'comp_phone': compPhone,
      'comp_pan_no': compPanNo,
      'comp_bill_addone': addressLine1,
      'comp_bill_city': city,
      'comp_bill_state': state,
      'comp_bill_pin': pin,
    };
  }
}
