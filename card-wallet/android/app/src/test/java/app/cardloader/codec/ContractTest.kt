package app.cardloader.codec

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

@Suppress("UNCHECKED_CAST")
class ContractTest {
    // A real 21 x 21 grid: the three position squares and nothing else dark.
    private fun finderGrid(n: Int = 21): Grid {
        val g = Array(n) { BooleanArray(n) }
        for ((r0, c0) in listOf(0 to 0, 0 to n - 7, n - 7 to 0)) {
            for (r in 0 until 7) for (c in 0 until 7) g[r0 + r][c0 + c] = maxOf(Math.abs(r - 3), Math.abs(c - 3)) != 2
        }
        return g
    }

    private fun qr(id: Int = 123, name: String = "Library", grid: Grid = finderGrid()) =
        QrCard.of(name, grid).toMessage(id).toMutableMap<String, Any?>()

    private fun bar(id: Int = 123, name: String = "Warehouse", t: String = "SAMPLE-CARD-0000") =
        BarCard(name, t).toMessage(id).toMutableMap<String, Any?>()

    @Test
    fun validMessagesPass() {
        assertEquals("", Contract.validate(qr()))
        assertEquals("", Contract.validate(bar()))
        assertEquals("", Contract.validate(qr(name = "A")))
        assertEquals("", Contract.validate(qr(name = "x".repeat(24))))
        assertEquals("", Contract.validate(qr(id = 1_000_000_000)))
        assertEquals("", Contract.validate(bar(t = "000012345678")))
        assertEquals("", Contract.validate(bar(t = "A".repeat(20))))
        assertEquals("", Contract.validate(bar(t = "a b")))
        assertEquals("", Contract.validate(qr(grid = finderGrid(177))))
    }

    @Test
    fun qrMessageHasExactlyTheContractsKeysAndIntValues() {
        val m = QrCard.of("Library", finderGrid()).toMessage(77)
        assertEquals(setOf("v", "id", "name", "kind", "n", "g"), m.keys)
        assertTrue(m["v"] is Int && m["id"] is Int && m["n"] is Int)
        assertEquals(1, m["v"]); assertEquals(77, m["id"]); assertEquals("qr", m["kind"]); assertEquals(21, m["n"])
        assertTrue(m["g"] is List<*>)
        assertEquals(21, (m["g"] as List<*>).size)
    }

    @Test
    fun barMessageHasExactlyTheContractsKeysAndIntValues() {
        val m = BarCard("Warehouse", "SAMPLE-CARD-0000").toMessage(5)
        assertEquals(setOf("v", "id", "name", "kind", "t"), m.keys)
        assertTrue(m["v"] is Int && m["id"] is Int)
        assertEquals("bar", m["kind"]); assertEquals("SAMPLE-CARD-0000", m["t"])
    }

    @Test
    fun storageMapsAreCardtoolsEntries() {
        assertEquals(setOf("name", "kind", "n", "g"), QrCard.of("Library", finderGrid()).toStorageMap().keys)
        assertEquals(setOf("name", "kind", "t"), BarCard("Warehouse", "1").toStorageMap().keys)
    }

    @Test
    fun formatCodes() {
        assertEquals("format", Contract.validate("not a dictionary"))
        assertEquals("format", Contract.validate(null))
        assertEquals("format", Contract.validate(qr().also { it["v"] = 2 }))
        assertEquals("format", Contract.validate(qr().also { it["v"] = 1L }))
        assertEquals("format", Contract.validate(qr().also { it.remove("id") }))
        assertEquals("format", Contract.validate(qr().also { it["id"] = 0 }))
        assertEquals("format", Contract.validate(qr().also { it["id"] = 1_000_000_001 }))
        assertEquals("format", Contract.validate(qr().also { it["id"] = 5L }))
        assertEquals("format", Contract.validate(qr().also { it["id"] = 5.0 }))
        assertEquals("format", Contract.validate(qr().also { it["extra"] = 1 }))
        assertEquals("format", Contract.validate(qr().also { it.remove("g") }))
        assertEquals("format", Contract.validate(qr().also { it["n"] = "21" }))
        assertEquals("format", Contract.validate(qr().also { it["g"] = listOf(1, 2) }))
        assertEquals("format", Contract.validate(bar().also { it.remove("t") }))
        assertEquals("format", Contract.validate(bar().also { it["t"] = 5 }))
        assertEquals("format", Contract.validate(bar().also { it["n"] = 21 }))
        assertEquals("format", Contract.validate(bar().also { it["name"] = 5 }))
    }

    @Test
    fun nameCode() {
        assertEquals("name", Contract.validate(qr(name = "")))
        assertEquals("name", Contract.validate(qr(name = "x".repeat(25))))
        assertEquals("name", Contract.validate(qr(name = "a\tb")))
        assertEquals("name", Contract.validate(qr(name = "a\u007fb")))
        assertEquals("name", Contract.validate(qr(name = " lead")))
        assertEquals("name", Contract.validate(qr(name = "trail ")))
        assertEquals("name", Contract.validate(bar(name = "")))
    }

    @Test
    fun kindCode() {
        assertEquals("kind", Contract.validate(qr().also { it["kind"] = "pdf" }))
        assertEquals("kind", Contract.validate(bar().also { it["kind"] = "QR" }))
    }

    @Test
    fun sizeCode() {
        assertEquals("size", Contract.validate(qr().also { it["n"] = 20 }))
        assertEquals("size", Contract.validate(qr().also { it["n"] = 22 }))
        assertEquals("size", Contract.validate(qr().also { it["n"] = 181 }))
        assertEquals("size", Contract.validate(qr().also { it["g"] = (it["g"] as List<*>).drop(1) }))
        assertEquals("size", Contract.validate(qr().also { m ->
            m["g"] = (m["g"] as List<String>).mapIndexed { i, s -> if (i == 3) s + "0" else s }
        }))
    }

    @Test
    fun charsCode() {
        assertEquals("chars", Contract.validate(qr().also { m ->
            m["g"] = (m["g"] as List<String>).mapIndexed { i, s -> if (i == 8) "G" + s.drop(1) else s }
        }))
        assertEquals("chars", Contract.validate(qr().also { m ->
            m["g"] = (m["g"] as List<String>).mapIndexed { i, s -> if (i == 8) "A" + s.drop(1) else s }
        }))
        // n = 21 has 3 unused bits in the last digit; a padding bit set.
        assertEquals("chars", Contract.validate(qr().also { m ->
            m["g"] = (m["g"] as List<String>).mapIndexed { i, s -> if (i == 10) s.dropLast(1) + "1" else s }
        }))
    }

    @Test
    fun shapeCode() {
        val g = finderGrid()
        g[0][0] = !g[0][0]
        assertEquals("shape", Contract.validate(qr(grid = g)))
        val withBottomRight = finderGrid()
        for (r in 0 until 7) for (c in 0 until 7) withBottomRight[14 + r][14 + c] = maxOf(Math.abs(r - 3), Math.abs(c - 3)) != 2
        assertEquals("shape", Contract.validate(qr(grid = withBottomRight)))
        assertEquals("shape", Contract.validate(qr(grid = Array(21) { BooleanArray(21) })))
    }

    @Test
    fun contentCode() {
        assertEquals("content", Contract.validate(bar(t = "")))
        assertEquals("content", Contract.validate(bar(t = "A".repeat(81))))
        assertEquals("content", Contract.validate(bar(t = "café")))
        assertEquals("content", Contract.validate(bar(t = "a\u0007b")))
    }

    @Test
    fun longCode() {
        // Estimated module width: 1 px at 20 characters, 0 px at 21.
        assertEquals("", Contract.validate(bar(t = "A".repeat(20))))
        assertEquals("long", Contract.validate(bar(t = "A".repeat(21))))
        assertEquals("long", Contract.validate(bar(t = "1".repeat(39))))
        assertEquals("", Contract.validate(bar(t = "1".repeat(40))))
    }

    @Test
    fun theFirstFailedRuleWinsInTheContractsOrder() {
        // name and kind both wrong: name comes first.
        assertEquals("name", Contract.validate(qr(name = "").also { it["kind"] = "x" }))
        // size and shape both wrong: size first.
        assertEquals("size", Contract.validate(qr(grid = Array(21) { BooleanArray(21) }).also { it["n"] = 22 }))
        // format beats name.
        assertEquals("format", Contract.validate(qr(name = "").also { it["v"] = 9 }))
    }

    @Test
    fun theFullCodeListIsCovered() {
        // every code of the contract except "full" (a watch-side storage failure) has a case above.
        assertEquals(listOf("format", "name", "kind", "size", "chars", "shape", "content", "long", "full"), Contract.WHY_CODES)
        for (code in Contract.WHY_CODES) assertTrue(Contract.whyText(code).isNotBlank())
    }

    @Test
    fun nameRuleAndCleanup() {
        assertNull(Contract.nameProblem("Library"))
        assertEquals("Library", Contract.cleanName("  Library  "))
        assertNull(Contract.nameProblem(Contract.cleanName("  Library  ")))
        assertTrue(Contract.nameProblem("") != null)
    }

    @Test
    fun idsAreInRange() {
        val random = Random(1)
        repeat(1000) { val id = Contract.newId(random); assertTrue(id in 1..1_000_000_000) }
    }

    @Test
    fun answersAreParsed() {
        val ok = WatchAnswer.parse(listOf(mapOf("id" to 5, "ok" to true, "why" to "")))
        assertEquals(WatchAnswer(5, true, ""), ok)
        val refused = WatchAnswer.parse(listOf(mapOf("id" to 5L, "ok" to false, "why" to "shape")))
        assertEquals(WatchAnswer(5, false, "shape"), refused)
        assertNull(WatchAnswer.parse(listOf("text")))
        assertNull(WatchAnswer.parse(emptyList<Any>()))
    }
}
