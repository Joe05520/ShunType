import Foundation

/// Standard ANSI physical keys. Decouples Daqian keystrokes from an already-active system IME.
public enum PhysicalKeyboard {
    private static let keys: [UInt16: String] = [
        0:"a",1:"s",2:"d",3:"f",4:"h",5:"g",6:"z",7:"x",8:"c",9:"v",11:"b",
        12:"q",13:"w",14:"e",15:"r",16:"y",17:"t",18:"1",19:"2",20:"3",21:"4",
        22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"o",
        32:"u",33:"[",34:"i",35:"p",37:"l",38:"j",39:"'",40:"k",41:";",42:"\\",
        43:",",44:"/",45:"n",46:"m",47:".",50:"`"
    ]
    private static let shifted: [String: String] = ["1":"!","2":"@","3":"#","4":"$","5":"%","6":"^","7":"&","8":"*","9":"(","0":")","-":"_","=":"+","[":"{","]":"}","\\":"|",";":":","'":"\"",",":"<",".":">","/":"?","`":"~"]
    public static func text(keyCode: UInt16, fallback: String, shift: Bool, capsLock: Bool) -> String {
        guard let base = keys[keyCode] else { return fallback }
        if base.first?.isLetter == true { return shift != capsLock ? base.uppercased() : base }
        return shift ? shifted[base] ?? base : base
    }
}
