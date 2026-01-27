import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final advapi32 = DynamicLibrary.open('advapi32.dll');

typedef AllocateAndInitializeSidC =
    Int32 Function(
      Pointer<Uint8> pIdentifierAuthority,
      Uint8 nSubAuthorityCount,
      Uint32 nSubAuthority0,
      Uint32 nSubAuthority1,
      Uint32 nSubAuthority2,
      Uint32 nSubAuthority3,
      Uint32 nSubAuthority4,
      Uint32 nSubAuthority5,
      Uint32 nSubAuthority6,
      Uint32 nSubAuthority7,
      Pointer<Pointer<Void>> pSid,
    );
typedef AllocateAndInitializeSidDart =
    int Function(
      Pointer<Uint8> pIdentifierAuthority,
      int nSubAuthorityCount,
      int nSubAuthority0,
      int nSubAuthority1,
      int nSubAuthority2,
      int nSubAuthority3,
      int nSubAuthority4,
      int nSubAuthority5,
      int nSubAuthority6,
      int nSubAuthority7,
      Pointer<Pointer<Void>> pSid,
    );

typedef FreeSidC = Pointer<Void> Function(Pointer<Void> pSid);
typedef FreeSidDart = Pointer<Void> Function(Pointer<Void> pSid);

typedef CheckTokenMembershipC =
    Int32 Function(
      Pointer<Void> TokenHandle,
      Pointer<Void> SidToCheck,
      Pointer<Int32> IsMember,
    );
typedef CheckTokenMembershipDart =
    int Function(
      Pointer<Void> TokenHandle,
      Pointer<Void> SidToCheck,
      Pointer<Int32> IsMember,
    );

final allocateAndInitializeSid = advapi32
    .lookupFunction<AllocateAndInitializeSidC, AllocateAndInitializeSidDart>(
      'AllocateAndInitializeSid',
    );
final freeSid = advapi32.lookupFunction<FreeSidC, FreeSidDart>('FreeSid');
final checkTokenMembership = advapi32
    .lookupFunction<CheckTokenMembershipC, CheckTokenMembershipDart>(
      'CheckTokenMembership',
    );

// Used to detect if this tool is ran as admin, if yes, it'll later be closed and relaunched as normal user (deprivilege)
bool isRunningAsAdmin() {
  if (!Platform.isWindows) return false;

  final sidAuth = calloc<Uint8>(6);
  sidAuth[5] = 5; // SECURITY_NT_AUTHORITY

  final sidPtr = calloc<Pointer<Void>>();
  final isMember = calloc<Int32>();

  final success = allocateAndInitializeSid(
    sidAuth,
    2,
    0x00000020, // SECURITY_BUILTIN_DOMAIN_RID
    0x00000220, // DOMAIN_ALIAS_RID_ADMINS
    0,
    0,
    0,
    0,
    0,
    0,
    sidPtr,
  );

  bool result = false;
  if (success != 0) {
    final check = checkTokenMembership(nullptr, sidPtr.value, isMember);
    if (check != 0) {
      result = isMember.value != 0;
    }
    freeSid(sidPtr.value);
  }

  calloc.free(sidAuth);
  calloc.free(sidPtr);
  calloc.free(isMember);

  return result;
}
