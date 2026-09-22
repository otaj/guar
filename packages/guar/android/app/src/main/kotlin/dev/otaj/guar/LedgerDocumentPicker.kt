// Storage Access Framework picker: the user grants persistable access to one ledger file.
package dev.otaj.guar

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

private const val CHANNEL_NAME = "dev.otaj.guar/ledger_documents"
private const val PREFS_NAME = "dev.otaj.guar.ledger"
private const val URI_KEY = "uri"
private const val NAME_KEY = "name"
private const val STARTER_LEDGER = "option \"title\" \"Ledger\"\n"
private const val FALLBACK_NAME = "ledger.beancount"
private const val READ_PERMISSION = Intent.FLAG_GRANT_READ_URI_PERMISSION
private const val WRITE_PERMISSION = Intent.FLAG_GRANT_WRITE_URI_PERMISSION

class LedgerDocumentPicker(
    private val activity: ComponentActivity,
) {
    private var pending: MethodChannel.Result? = null

    private val openLauncher =
        activity.registerForActivityResult(OpenLedgerContract()) { picked ->
            deliver(picked, starter = null)
        }

    private val createLauncher =
        activity.registerForActivityResult(CreateLedgerContract()) { picked ->
            deliver(picked, starter = STARTER_LEDGER)
        }

    fun attach(engine: FlutterEngine) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(current())
                "open" -> beginPick(result) { openLauncher.launch(Unit) }
                "create" -> beginPick(result) { createLauncher.launch(Unit) }
                else -> result.notImplemented()
            }
        }
    }

    private fun beginPick(
        result: MethodChannel.Result,
        start: () -> Unit,
    ) {
        if (pending != null) {
            result.error("busy", "A file picker is already open.", null)
            return
        }
        pending = result
        try {
            start()
        } catch (caught: ActivityNotFoundException) {
            pending = null
            result.error(
                "unavailable",
                "No file picker is available on this device.",
                caught.message,
            )
        }
    }

    private fun deliver(
        picked: PickedLedger?,
        starter: String?,
    ) {
        val result = pending ?: return
        pending = null
        if (picked == null) {
            result.success(null)
            return
        }
        try {
            persist(picked.uri, picked.flags)
            if (starter != null) {
                write(picked.uri, starter)
            }
            val name = displayName(picked.uri)
            remember(picked.uri, name)
            result.success(mapOf("uri" to picked.uri.toString(), "name" to name))
        } catch (caught: SecurityException) {
            result.error(
                "permission_denied",
                "Guar was not allowed to keep access to that file.",
                caught.message,
            )
        } catch (caught: IOException) {
            result.error(
                "write_failed",
                "Guar could not write the new ledger.",
                caught.message,
            )
        }
    }

    private fun persist(
        uri: Uri,
        grantedFlags: Int,
    ) {
        val granted = grantedFlags and (READ_PERMISSION or WRITE_PERMISSION)
        val both = READ_PERMISSION or WRITE_PERMISSION
        val attempts = mutableListOf<Int>()
        if (granted != 0) {
            attempts.add(granted)
        }
        if (granted != both) {
            attempts.add(both)
        }
        if (!attempts.contains(READ_PERMISSION)) {
            attempts.add(READ_PERMISSION)
        }
        var failure: SecurityException? = null
        for (flags in attempts) {
            try {
                activity.contentResolver.takePersistableUriPermission(uri, flags)
                return
            } catch (caught: SecurityException) {
                failure = caught
            }
        }
        throw failure ?: SecurityException("Guar was not allowed to keep access to that file.")
    }

    private fun write(
        uri: Uri,
        text: String,
    ) {
        val stream =
            activity.contentResolver.openOutputStream(uri)
                ?: throw IOException("Guar could not write the new ledger.")
        stream.use { output ->
            output.write(text.toByteArray(Charsets.UTF_8))
        }
    }

    private fun displayName(uri: Uri): String {
        val queried = queryDisplayName(uri)
        if (!queried.isNullOrEmpty()) {
            return queried
        }
        val segment = uri.lastPathSegment
        if (!segment.isNullOrEmpty()) {
            return segment
        }
        return FALLBACK_NAME
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor =
            activity.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            ) ?: return null
        return cursor.use { rows ->
            if (!rows.moveToFirst()) {
                return@use null
            }
            val index = rows.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) {
                null
            } else {
                rows.getString(index)
            }
        }
    }

    private fun remember(
        uri: Uri,
        name: String,
    ) {
        activity
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(URI_KEY, uri.toString())
            .putString(NAME_KEY, name)
            .apply()
    }

    private fun current(): Map<String, String>? {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val stored = prefs.getString(URI_KEY, null) ?: return null
        val uri = Uri.parse(stored)
        val granted =
            activity.contentResolver.persistedUriPermissions.any { permission ->
                permission.uri == uri && permission.isReadPermission
            }
        if (!granted) {
            prefs.edit().clear().apply()
            return null
        }
        val storedName = prefs.getString(NAME_KEY, null)
        val name =
            if (storedName.isNullOrEmpty()) {
                displayName(uri)
            } else {
                storedName
            }
        return mapOf("uri" to uri.toString(), "name" to name)
    }
}

private data class PickedLedger(
    val uri: Uri,
    val flags: Int,
)

private class OpenLedgerContract : ActivityResultContract<Unit, PickedLedger?>() {
    override fun createIntent(
        context: Context,
        input: Unit,
    ): Intent = openOrCreate(Intent.ACTION_OPEN_DOCUMENT, suggestedName = null)

    override fun parseResult(
        resultCode: Int,
        intent: Intent?,
    ): PickedLedger? = picked(resultCode, intent)
}

private class CreateLedgerContract : ActivityResultContract<Unit, PickedLedger?>() {
    override fun createIntent(
        context: Context,
        input: Unit,
    ): Intent = openOrCreate(Intent.ACTION_CREATE_DOCUMENT, suggestedName = FALLBACK_NAME)

    override fun parseResult(
        resultCode: Int,
        intent: Intent?,
    ): PickedLedger? = picked(resultCode, intent)
}

private fun openOrCreate(
    action: String,
    suggestedName: String?,
): Intent {
    val intent =
        Intent(action).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type =
                if (suggestedName == null) {
                    "*/*"
                } else {
                    "application/octet-stream"
                }
            addFlags(READ_PERMISSION)
            addFlags(WRITE_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
    if (suggestedName != null) {
        intent.putExtra(Intent.EXTRA_TITLE, suggestedName)
    }
    return intent
}

private fun picked(
    resultCode: Int,
    intent: Intent?,
): PickedLedger? {
    if (resultCode != Activity.RESULT_OK) {
        return null
    }
    val data = intent ?: return null
    val uri = data.data ?: return null
    return PickedLedger(uri, data.flags)
}
