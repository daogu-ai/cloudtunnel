import Foundation

enum Lang { case zh, en }

/// 跟随系统语言：首选语言以 zh 开头用中文，否则英文。
let appLang: Lang = {
    let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
    return first.hasPrefix("zh") ? .zh : .en
}()

/// 行内双语：L("中文", "English")。
func L(_ zh: String, _ en: String) -> String { appLang == .zh ? zh : en }
