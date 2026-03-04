import Darwin

enum MachError: Error {
    case hostStatisticsFailed(kern_return_t)
}

func hostStatistics64<T>(
    _ host: host_t,
    flavor: host_flavor_t,
    as type: T.Type
) throws -> T {
    var size = mach_msg_type_number_t(
        MemoryLayout<T>.size / MemoryLayout<integer_t>.size
    )
    let data = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { data.deallocate() }

    let result = data.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { ptr in
        Darwin.host_statistics64(host, flavor, ptr, &size)
    }
    guard result == KERN_SUCCESS else {
        throw MachError.hostStatisticsFailed(result)
    }
    return data.pointee
}
