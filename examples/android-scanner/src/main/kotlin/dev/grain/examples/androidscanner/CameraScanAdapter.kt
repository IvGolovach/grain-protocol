package dev.grain.examples.androidscanner

enum class CameraScanSource {
    Camera,
    Injected,
}

data class CameraScanPayload(
    val qrString: String,
    val source: CameraScanSource,
)

interface CameraScanAdapter<FrameT> {
    fun decode(frame: FrameT): CameraScanPayload?
}

class CameraXFrameScanAdapter<FrameT>(
    private val decodeQrString: (FrameT) -> String?,
) : CameraScanAdapter<FrameT> {
    override fun decode(frame: FrameT): CameraScanPayload? {
        val qrString = decodeQrString(frame)?.trim().orEmpty()
        if (qrString.isEmpty()) {
            return null
        }
        return CameraScanPayload(qrString = qrString, source = CameraScanSource.Camera)
    }
}

class InjectedCameraScanAdapter(
    qrStrings: List<String>,
) : CameraScanAdapter<Unit> {
    private val pending = ArrayDeque(qrStrings)

    override fun decode(frame: Unit): CameraScanPayload? =
        nextScanPayload()

    fun nextScanPayload(): CameraScanPayload? {
        val qrString = pending.removeFirstOrNull()?.trim().orEmpty()
        if (qrString.isEmpty()) {
            return null
        }
        return CameraScanPayload(qrString = qrString, source = CameraScanSource.Injected)
    }
}
