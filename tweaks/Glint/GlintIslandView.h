#import <UIKit/UIKit.h>

// Glint — Dynamic Island for iOS 12 notchless devices.
// UI engine mirroring the real island's behavior ( researched from Apple HIG ):
//   • idle: a small opaque black pill floating near the clock, always present
//   • notifications: auto-expand banner + collapse, app glyph stays in the left
//     half of the compact pill (like the leading Live Activity slot)
//   • now playing: animated waveform bars in the right half (trailing slot)
//   • live timer: countdown timer with ⏱ icon near the clock
//   • glow engine: rainbow cycle, 1s breathing blink, custom backlight
//   • beat pulse: breathing scale on the pill during music
//   • tap → open the related app; long-press → full expanded card
// All methods must be called on the main thread (they dispatch there themselves).
// Version 1.2.3: live timer + glow engine + beat pulse + full settings pane.

@interface GlintIsland : NSObject

+ (instancetype)shared;

// Creates the island window. Safe to call multiple times; meant to run shortly
// after SpringBoard -applicationDidFinishLaunching: to avoid boot crashes.
- (void)setup;

- (BOOL)isSetup;

// Pill size preset: 0 = small, 1 = normal, 2 = large. Applied live.
- (void)applySizePreset:(NSInteger)preset;

// Hide the whole island window (prefs off) / bring it back.
- (void)setIslandHidden:(BOOL)hidden;

// Notification-style event: island bounces open for a few seconds, then
// collapses; the app glyph remains visible in the compact left slot.
- (void)showEventForApp:(NSString *)appName
                 bundle:(NSString *)bundleID
                  glyph:(NSString *)glyph
                   icon:(UIImage *)icon
                  title:(NSString *)title
                message:(NSString *)message;

// Charging pill (real DI style: appears when the charger is plugged).
- (void)showChargingAtLevel:(NSInteger)levelPercent;

// Persistent ⚡ in the left slot while a charger is attached (nil on unplug).
- (void)setChargingSlotLevel:(NSInteger)levelPercent orNil:(BOOL)clear;

// Torch indicator.
- (void)showTorchOn:(BOOL)on;

// Now playing expand (music card + bars reminder in the right slot).
- (void)showNowPlayingTrack:(NSString *)track artist:(NSString *)artist;

// Boot "hello" (marks version online, proves pipeline works).
- (void)showBootGreeting;

// Waveform bars inside the collapsed pill while audio plays.
- (void)setNowPlayingActive:(BOOL)active;
- (BOOL)isNowPlayingActive;

// Live timer countdown near the clock.
- (void)showTimerCountdown:(NSInteger)remainingSeconds;
- (void)showTimerDone;
- (void)clearTimerCountdown;

// Glow engine & cosmetic pulse reloader.
- (void)applyGlowPrefs;

// Fallback tap when there is nothing to open: subtle heartbeat pulse.
- (void)playIdleTapPulse;

@end
