import Testing
@testable import CleanMyScreenKit

@Test("All three modes remain first-class and free")
func exposesThreeModes() {
    #expect(LockMode.allCases == [.cleaning, .petKid, .selective])
    #expect(!LockMode.cleaning.hidesApplicationOnActivation)
    #expect(LockMode.petKid.hidesApplicationOnActivation)
    #expect(LockMode.selective.hidesApplicationOnActivation)
    #expect(!LockMode.cleaning.hidesApplicationWhenCountdownBegins)
    #expect(LockMode.petKid.hidesApplicationWhenCountdownBegins)
    #expect(!LockMode.selective.hidesApplicationWhenCountdownBegins)
    #expect(LockMode.cleaning.countdownSeconds == 3)
    #expect(LockMode.petKid.countdownSeconds == 5)
    #expect(LockMode.selective.countdownSeconds == 3)
}

@Test("Cleaning defaults match the selected prototype")
func cleaningDefaults() {
    let configuration = LockConfiguration(mode: .cleaning)

    #expect(configuration.allDisplays)
    #expect(configuration.maximizeBrightness)
    #expect(configuration.autoUnlockSeconds == 60)
}

@Test("Selective mode requires at least one target")
func selectiveSelection() {
    #expect(SelectiveLockConfiguration().hasSelection)
    #expect(!SelectiveLockConfiguration(keyboard: false, trackpad: false, externalDevices: false).hasSelection)
}

@Test("Input masks compose without losing categories")
func inputMaskComposition() {
    let mask: InputBlockMask = [.keyboard, .scrolling]

    #expect(mask.contains(.keyboard))
    #expect(mask.contains(.scrolling))
    #expect(!mask.contains(.pointer))
}
