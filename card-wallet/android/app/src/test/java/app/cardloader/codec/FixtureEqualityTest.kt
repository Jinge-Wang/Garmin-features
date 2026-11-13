package app.cardloader.codec

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File
import javax.imageio.ImageIO

/**
 * Equality with the Mac tool. The fixtures are cardtool's input (`list.json`, the pictures) and
 * its output (`expected.json`); the phone's pipeline must produce the same records.
 */
class FixtureEqualityTest {
    private val folder = File(System.getProperty("cardloader.fixtures") ?: "fixtures")

    private fun parse(file: File): JsonElement = Json.parseToJsonElement(file.readText())

    private fun record(o: JsonObject): Map<String, Any> {
        val out = linkedMapOf<String, Any>()
        for ((key, value) in o) {
            out[key] = when (key) {
                "n" -> value.jsonPrimitive.int
                "g" -> value.jsonArray.map { it.jsonPrimitive.content }
                else -> value.jsonPrimitive.content
            }
        }
        return out
    }

    @Test
    fun everyCardOfTheListEqualsCardtoolsRecord() {
        val listFile = File(folder, "list.json")
        val expectedFile = File(folder, "expected.json")
        if (!listFile.exists() || !expectedFile.exists()) {
            fail("fixtures are not in place (list.json and expected.json are needed in the fixtures folder)")
        }
        val listRoot = parse(listFile)
        val entries: JsonArray = if (listRoot is JsonArray) listRoot else listRoot.jsonObject["cards"]!!.jsonArray
        val expectedByName = parse(expectedFile).jsonObject["cards"]!!.jsonArray
            .map { record(it.jsonObject) }.associateBy { it["name"] as String }

        val problems = ArrayList<String>()
        var compared = 0
        for (element in entries) {
            val entry = element.jsonObject
            val name = entry["name"]!!.jsonPrimitive.content.trim()
            val expected = expectedByName[name]
            if (expected == null) {
                problems.add("$name: not in expected.json")
                continue
            }
            val card: Card = when {
                entry.containsKey("image") -> {
                    val image = ImageIO.read(File(folder, entry["image"]!!.jsonPrimitive.content))
                    val outcome = CodeReader.read(TestSupport.lumaOf(image), thorough = true)
                    if (outcome !is ReadOutcome.Qr) {
                        problems.add("$name: the phone's pipeline did not produce a QR code (${outcome::class.simpleName})")
                        continue
                    }
                    QrCard.of(name, outcome.symbol.grid)
                }
                entry.containsKey("number") -> {
                    val content = BarContent.fromTyped(entry["number"]!!.jsonPrimitive.content)
                    val problem = BarContent.problem(content)
                    if (problem != null) {
                        problems.add("$name: $problem")
                        continue
                    }
                    BarCard(name, content)
                }
                else -> {
                    problems.add("$name: the entry has neither image nor number")
                    continue
                }
            }
            compared++
            val why = Contract.validate(card.toMessage(7))
            if (why.isNotEmpty()) problems.add("$name: the message breaks the contract's rule \"$why\"")
            val actual = card.toStorageMap()
            if (actual != expected) {
                val a = actual["g"] as? List<*>
                val e = expected["g"] as? List<*>
                val detail = if (a != null && e != null && actual["n"] == expected["n"]) {
                    val n = expected["n"] as Int
                    val differing = Grids.differences(
                        Grids.fromHexRows(a.map { it as String }, n), Grids.fromHexRows(e.map { it as String }, n),
                    )
                    "grid ${n} x $n, $differing modules differ"
                } else {
                    "actual ${actual.filterKeys { it != "g" }} (grid size ${a?.size}), expected ${expected.filterKeys { it != "g" }} (grid size ${e?.size})"
                }
                problems.add("$name: $detail")
            }
        }
        assertTrue("no card was compared", compared > 0)
        if (problems.isNotEmpty()) fail("${problems.size} of ${entries.size} cards differ from cardtool:\n" + problems.joinToString("\n"))
    }
}
