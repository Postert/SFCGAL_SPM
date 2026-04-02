#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif

import CSFCGAL_Shim

public func sfcgalVersion() -> String {
    return String(cString: sfcgal_version())
}
