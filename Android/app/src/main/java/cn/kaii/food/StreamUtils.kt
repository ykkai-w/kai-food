package cn.kaii.food

import java.io.InputStream
import java.io.ByteArrayOutputStream

fun InputStream.readLimitedBytes(limit: Int): ByteArray {
    val output = ByteArrayOutputStream()
    val buffer = ByteArray(8192)
    while (output.size() < limit) {
        val count = read(buffer, 0, minOf(buffer.size, limit - output.size()))
        if (count == -1) break
        output.write(buffer, 0, count)
    }
    return output.toByteArray()
}
