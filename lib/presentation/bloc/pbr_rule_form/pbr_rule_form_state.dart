// lib/presentation/bloc/pbr_rule_form/pbr_rule_form_state.dart
import 'package:equatable/equatable.dart';
import 'package:load_balance/domain/entities/access_control_list.dart';
import 'package:load_balance/domain/entities/route_map.dart';
import 'package:load_balance/domain/entities/router_interface.dart';
import 'package:load_balance/presentation/bloc/load_balancing/load_balancing_state.dart'
    show DataStatus;

enum PbrActionType { nextHop, interface }

enum AclSelectionMode { createNew, selectExisting }

class PbrRuleFormState extends Equatable {
  final bool isEditing;
  final RouteMap? initialRule;
  // وضعیت کلی فرم
  final DataStatus formStatus;
  final String? errorMessage;
  final String? successMessage;
  // Holds the successfully submitted rule to be passed back.
  final RouteMap? submittedRule;
  // **تغییر ۱: این فیلد برای نگهداری ACL جدید اضافه شده است**
  final AccessControlList? submittedAcl; 

  // داده‌های اولیه که از صفحه قبل می‌آیند
  final List<RouterInterface> availableInterfaces;
  final List<AccessControlList> existingAcls;
  final List<RouteMap> existingRouteMaps;
  // -- بخش انتخاب Access-List --
  final AclSelectionMode aclMode;
  final String? selectedAclId;
  // ID ی ACL انتخاب شده از لیست موجود

  // -- بخش ساخت Access-List جدید --
  final String newAclId;
  final String? newAclIdError;
  final List<AclEntry> newAclEntries; // لیست موقت برای ساخت ACL جدید

  // -- بخش Route-Map --
  final String ruleName;
  // نام Route-Map
  final String? ruleNameError;
  final PbrActionType actionType;
  final String nextHop;
  final String? nextHopError;
  final String egressInterface;
  final String applyToInterface;

  const PbrRuleFormState({
    this.isEditing = false,
    this.initialRule,
    this.formStatus = DataStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.submittedRule,
    this.submittedAcl, // **تغییر ۲: مقداردهی اولیه در کانستراکتور**
    this.availableInterfaces = const [],
    this.existingAcls = const [],
    this.existingRouteMaps = const [],
    this.aclMode = AclSelectionMode.createNew,
    this.selectedAclId,
    this.newAclId = '101', // یک مقدار پیش‌فرض
    this.newAclIdError,
    this.newAclEntries = const [
      // همیشه با یک entry خالی شروع می‌کنیم
      AclEntry(
        sequence: 1,
        permission: 'permit',
        protocol: 'ip',
        source: 'any',
        destination: 'any',
      ),
    ],
    this.ruleName = '',
    this.ruleNameError,
    this.actionType = PbrActionType.nextHop,
    this.nextHop = '',
    this.nextHopError,
    this.egressInterface = '',
    this.applyToInterface = '',
  });
  /// A getter to determine if the form is valid and can be submitted.
  bool get isFormValid {
    if (ruleName.trim().isEmpty) return false;
    if (ruleNameError != null) return false;
    if (aclMode == AclSelectionMode.createNew) {
      if (newAclId.trim().isEmpty || newAclIdError != null) return false;
      if (newAclEntries.isEmpty) return false;
    } else {
      // selectExisting
      if (selectedAclId == null) return false;
    }

    if (actionType == PbrActionType.nextHop) {
      if (nextHop.trim().isEmpty || nextHopError != null) return false;
    } else {
      // interface
      if (egressInterface.isEmpty) return false;
    }

    return applyToInterface.isNotEmpty;
  }

  PbrRuleFormState copyWith({
    bool? isEditing,
    RouteMap? initialRule,
    DataStatus? formStatus,
    String? errorMessage,
    String? successMessage,
    RouteMap? submittedRule,
    AccessControlList? submittedAcl, // **تغییر ۳: پارامتر جدید به copyWith اضافه شد**
    List<RouterInterface>? availableInterfaces,
    List<AccessControlList>? existingAcls,
    List<RouteMap>? existingRouteMaps,
    AclSelectionMode? aclMode,
    String? selectedAclId,
    bool clearSelectedAclId = false,
    String? newAclId,
    String? newAclIdError,
    List<AclEntry>? newAclEntries,
    String? ruleName,
    String? ruleNameError,
    PbrActionType? actionType,
    String? nextHop,
    String? nextHopError,
    String? egressInterface,
    String? applyToInterface,
  }) {
    return PbrRuleFormState(
      isEditing: isEditing ?? this.isEditing,
      initialRule: initialRule ?? this.initialRule,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage,
      successMessage: successMessage,
      submittedRule: submittedRule ?? this.submittedRule,
      submittedAcl: submittedAcl ?? this.submittedAcl, // **تغییر ۴: مقداردهی فیلد جدید**
      availableInterfaces: availableInterfaces ?? this.availableInterfaces,
      existingAcls: existingAcls ?? this.existingAcls,
      existingRouteMaps: existingRouteMaps ?? this.existingRouteMaps,
      aclMode: aclMode ?? this.aclMode,
      selectedAclId: clearSelectedAclId
          ? null
          : selectedAclId ?? this.selectedAclId,
      newAclId: newAclId ?? this.newAclId,
      newAclIdError: newAclIdError,
      newAclEntries: newAclEntries ?? this.newAclEntries,
      ruleName: ruleName ?? this.ruleName,
      ruleNameError: ruleNameError,
      actionType: actionType ?? this.actionType,
      nextHop: nextHop ?? this.nextHop,
      nextHopError: nextHopError,
      egressInterface: egressInterface ?? this.egressInterface,
      applyToInterface: applyToInterface ?? this.applyToInterface,
    );
  }

  @override
  List<Object?> get props => [
    formStatus,
    errorMessage,
    successMessage,
    submittedRule,
    submittedAcl, // **تغییر ۵: اضافه شدن به props برای مقایسه صحیح state**
    availableInterfaces,
    existingAcls,
    existingRouteMaps,
    aclMode,
    selectedAclId,
    newAclId,
    newAclIdError,
    newAclEntries,
    ruleName,
    ruleNameError,
    actionType,
    nextHop,
    nextHopError,
    egressInterface,
    applyToInterface,
    isEditing,
    initialRule,
  ];
}