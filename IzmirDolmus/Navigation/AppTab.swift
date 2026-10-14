/// Uygulamanın kök sekmeleri. Her sekmenin kendi gezinme yığını vardır.
enum AppTab: Hashable, CaseIterable {
    case home
    case map
    case hats
    case favorites
    case settings
}
