// Flutter host. Fragment activity so the ledger picker can use activity results.
package dev.otaj.guar

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val ledgerDocuments = LedgerDocumentPicker(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ledgerDocuments.attach(flutterEngine)
    }
}
