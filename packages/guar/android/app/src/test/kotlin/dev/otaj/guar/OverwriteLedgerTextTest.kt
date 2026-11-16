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

    @Test
    fun backupReplacesThePreviousCopy() {
        val dir = Files.createTempDirectory("ledger-backup").toFile()
        writeBackup(dir, "ledger.beancount", "one\n".toByteArray())
        writeBackup(dir, "ledger.beancount", "two\n".toByteArray())
        assertEquals("two\n", File(dir, "ledger.beancount").readText())
        dir.deleteRecursively()
    }

    @Test
    fun backupKeepsThePreviousGeneration() {
        val dir = Files.createTempDirectory("ledger-backup").toFile()
        // The disk holds the last good content when the backup runs.
        writeBackup(dir, "ledger.beancount", "good\n".toByteArray())
        // The next save starts from an interrupted, broken file; the backup must keep the good copy.
        writeBackup(dir, "ledger.beancount", "broken\n".toByteArray())
        assertEquals("broken\n", File(dir, "ledger.beancount").readText())
        assertEquals("good\n", File(dir, "ledger.beancount.old").readText())
        dir.deleteRecursively()
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
