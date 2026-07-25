import 'package:connect_app/call_v2/runtime/call_v2_runtime_dependency_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest declares every runtime dependency without allocation', () {
    const manifest = CallV2RuntimeDependencyManifest.developerOnly;

    expect(manifest.complete, isTrue);
    expect(manifest.allocatesProductionDependencies, isFalse);
    expect(manifest.requiredKinds,
        containsAll(CallV2RuntimeDependencyKind.values));
    expect(manifest.requirements,
        hasLength(CallV2RuntimeDependencyKind.values.length));
  });

  test('safe debug output contains only counts and booleans', () {
    final debug =
        CallV2RuntimeDependencyManifest.developerOnly.toSafeDebugMap();

    expect(debug, <String, Object?>{
      'requirementCount': CallV2RuntimeDependencyKind.values.length,
      'complete': true,
      'allocatesProductionDependencies': false,
    });
  });
}
