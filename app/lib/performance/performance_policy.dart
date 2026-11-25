/// A default profile, not a benchmark score. Android owns the classification.
enum DeviceTier { low, medium, high }

enum TextAnimationDelete { fallAway, dust, none }

enum TextAnimationCursor { glide, steady }

enum PerformanceMode { auto, full, light }

class PerformanceSnapshot {
  const PerformanceSnapshot({
    this.sequence = -1,
    this.device = const {},
    this.thermal = const {},
    this.loaded = false,
    this.available = false,
  });

  factory PerformanceSnapshot.fromMap(Map<Object?, Object?> raw) {
    Map<String, Object?> section(Object? value) => value is Map
        ? {
            for (final entry in value.entries)
              if (entry.key is String) entry.key as String: entry.value,
          }
        : const {};
    return PerformanceSnapshot(
      sequence: (raw['sequence'] as num?)?.toInt() ?? 0,
      device: section(raw['device']),
      thermal: section(raw['thermal']),
      loaded: raw['device'] is Map,
      available: true,
    );
  }

  final int sequence;
  final Map<String, Object?> device;
  final Map<String, Object?> thermal;
  final bool loaded;
  final bool available;

  DeviceTier get tier => DeviceTier.values.asNameMap()[device['tier']] ?? DeviceTier.medium;
  bool get thermalLightweight => thermal['lightweight'] == true;

  Map<String, Object?> toMap() => {'available': available, 'loaded': loaded, 'device': device, 'thermal': thermal};
}

/// 屏幕刷新率(设置 → 性能)。有些系统把第三方 App 默认压在 60Hz;App 一旦声明
/// 自己管刷新率,系统就会把开关显示成「应用内设置」——所以这里必须真的给用户一个
/// 选择,包括「跟随系统」把决定权还回去。
enum RefreshRateMode {
  /// 动画、滚动、流式输出时用屏幕最高刷新率;停下来交回系统。
  auto,

  /// 一直用最高刷新率。
  max,

  /// 不声明偏好,完全由系统的刷新率设置决定。
  system,
}

/// Null per-feature values mean "use the current profile". Defaults are never persisted.
class PerformancePrefs {
  const PerformancePrefs({
    this.mode = PerformanceMode.auto,
    this.blur,
    this.animations,
    this.fluid,
    this.refreshRate = RefreshRateMode.auto,
    this.frameCache = true,
    this.textAnimation = false,
    this.textAnimationSpeed = 320,
    this.textAnimationSlide = 10,
    this.textAnimationDelete = TextAnimationDelete.fallAway,
    this.textAnimationCursor = TextAnimationCursor.glide,
    this.textAnimationLetters = true,
    this.textAnimationSlideUp = true,
    this.textAnimationUnblur = false,
    this.textAnimationPop = false,
    this.textAnimationTilt = false,
    this.textAnimationTrail = true,
    this.textAnimationCursorSpeed = 18,
    this.textAnimationPopStrength = 100,
    this.textAnimationTiltStrength = 100,
    this.textAnimationEveryField = false,
    this.loaded = false,
  });

  final PerformanceMode mode;
  final bool? blur;
  final bool? animations;

  /// 灵动动效(见 `AppMotion.fluid`)。
  final bool? fluid;
  final RefreshRateMode refreshRate;

  /// HarmonyOS's engine holds back one frame to smooth rate changes, at slightly more touch
  /// delay. A switch because the difference can only be judged on a device.
  final bool frameCache;

  /// Per-letter animation in the chat composer. Opt-in: it hides the native
  /// text and repaints every glyph, so it stays off until the user asks for it.
  final bool textAnimation;
  final int textAnimationSpeed;
  final double textAnimationSlide;
  final TextAnimationDelete textAnimationDelete;
  final TextAnimationCursor textAnimationCursor;
  final bool textAnimationLetters;
  final bool textAnimationSlideUp;
  final bool textAnimationUnblur;
  final bool textAnimationPop;
  final bool textAnimationTilt;
  final bool textAnimationTrail;
  final int textAnimationCursorSpeed;
  final int textAnimationPopStrength;
  final int textAnimationTiltStrength;
  final bool textAnimationEveryField;
  final bool loaded;

  PerformancePrefs copyWith({
    PerformanceMode? mode,
    bool? blur,
    bool? animations,
    bool? fluid,
    RefreshRateMode? refreshRate,
    bool? frameCache,
    bool? textAnimation,
    int? textAnimationSpeed,
    double? textAnimationSlide,
    TextAnimationDelete? textAnimationDelete,
    TextAnimationCursor? textAnimationCursor,
    bool? textAnimationLetters,
    bool? textAnimationSlideUp,
    bool? textAnimationUnblur,
    bool? textAnimationPop,
    bool? textAnimationTilt,
    bool? textAnimationTrail,
    int? textAnimationCursorSpeed,
    int? textAnimationPopStrength,
    int? textAnimationTiltStrength,
    bool? textAnimationEveryField,
    bool? loaded,
    bool resetEffects = false,
  }) => PerformancePrefs(
    mode: mode ?? this.mode,
    blur: resetEffects ? null : blur ?? this.blur,
    animations: resetEffects ? null : animations ?? this.animations,
    fluid: resetEffects ? null : fluid ?? this.fluid,
    refreshRate: refreshRate ?? this.refreshRate,
    frameCache: frameCache ?? this.frameCache,
    textAnimation: resetEffects ? false : textAnimation ?? this.textAnimation,
    textAnimationSpeed: resetEffects ? 320 : textAnimationSpeed ?? this.textAnimationSpeed,
    textAnimationSlide: resetEffects ? 10 : textAnimationSlide ?? this.textAnimationSlide,
    textAnimationDelete: resetEffects ? TextAnimationDelete.fallAway : textAnimationDelete ?? this.textAnimationDelete,
    textAnimationCursor: resetEffects ? TextAnimationCursor.glide : textAnimationCursor ?? this.textAnimationCursor,
    textAnimationLetters: resetEffects ? true : textAnimationLetters ?? this.textAnimationLetters,
    textAnimationSlideUp: resetEffects ? true : textAnimationSlideUp ?? this.textAnimationSlideUp,
    textAnimationUnblur: resetEffects ? false : textAnimationUnblur ?? this.textAnimationUnblur,
    textAnimationPop: resetEffects ? false : textAnimationPop ?? this.textAnimationPop,
    textAnimationTilt: resetEffects ? false : textAnimationTilt ?? this.textAnimationTilt,
    textAnimationTrail: resetEffects ? true : textAnimationTrail ?? this.textAnimationTrail,
    textAnimationCursorSpeed: resetEffects ? 18 : textAnimationCursorSpeed ?? this.textAnimationCursorSpeed,
    textAnimationPopStrength: resetEffects ? 100 : textAnimationPopStrength ?? this.textAnimationPopStrength,
    textAnimationTiltStrength: resetEffects ? 100 : textAnimationTiltStrength ?? this.textAnimationTiltStrength,
    textAnimationEveryField: resetEffects ? false : textAnimationEveryField ?? this.textAnimationEveryField,
    loaded: loaded ?? this.loaded,
  );
}

class PerformanceDefaults {
  const PerformanceDefaults({
    required this.lightweight,
    required this.blur,
    required this.reduceMotion,
    required this.fluidMotion,
    required this.petEnabled,
    required this.autoStartLocal,
    required this.recommendRemote,
  });

  factory PerformanceDefaults.resolve(PerformanceSnapshot snapshot, PerformancePrefs prefs) {
    final light =
        snapshot.thermalLightweight ||
        switch (prefs.mode) {
          PerformanceMode.auto => snapshot.tier == DeviceTier.low,
          PerformanceMode.full => false,
          PerformanceMode.light => true,
        };
    final reduceMotion = !(prefs.animations ?? !light);
    return PerformanceDefaults(
      lightweight: light,
      blur: prefs.blur ?? !light,
      reduceMotion: reduceMotion,
      fluidMotion: !reduceMotion && (prefs.fluid ?? !light),
      petEnabled: !light,
      autoStartLocal: !light,
      recommendRemote: light || snapshot.tier == DeviceTier.low,
    );
  }

  final bool lightweight;
  final bool blur;
  final bool reduceMotion;

  /// 灵动档:动效没关,且用户选了或当前档位默认开(低端机、发热时默认关)。
  final bool fluidMotion;
  final bool petEnabled;
  final bool autoStartLocal;
  final bool recommendRemote;

  /// Reserved for 7b. No tier opts into extra background residency by default.
  bool get keepEngineInBackground => false;

  Map<String, Object?> toMap() => {
    'lightweight': lightweight,
    'blur': blur,
    'reduceMotion': reduceMotion,
    'fluidMotion': fluidMotion,
    'petEnabledDefault': petEnabled,
    'autoStartLocalDefault': autoStartLocal,
    'recommendRemote': recommendRemote,
    'keepEngineInBackgroundDefault': keepEngineInBackground,
  };
}
