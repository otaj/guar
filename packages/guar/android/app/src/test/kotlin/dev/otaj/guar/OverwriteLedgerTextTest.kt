// A shorter ledger rewrite must not keep the previous file's tail.
package dev.otaj.guar

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files

class OverwriteLedgerTextTest {
    @Test
    fun shorterRewriteDropsTheOldTail() {
        val file = Files.createTempFile("ledger", ".beancount").toFile()
        file.writeText("option \"title\" \"Example Beancount file\"\nquery\n")
        rewrite(file, "option \"title\" \"Example\"\nquery\n")
        assertEquals("option \"title\" \"Example\"\nquery\n", file.readText())
        file.delete()
    }

    @Test
    fun longerRewriteKeepsTheNewEnding() {
        val file = Files.createTempFile("ledger", ".beancount").toFile()
        file.writeText("option \"title\" \"X\"\n")
        rewrite(file, "option \"title\" \"Example Beancount file\"\nquery\n")
        assertEquals("option \"title\" \"Example Beancount file\"\nquery\n", file.readText())
        file.delete()
    }

    private fun rewrite(
        file: File,
        text: String,
    ) {
        RandomAccessFile(file, "rw").use { access ->
            overwriteLedgerText(access.channel, text)
        }
    }
}
