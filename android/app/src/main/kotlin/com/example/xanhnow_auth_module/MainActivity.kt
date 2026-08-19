package com.example.xanhnow_auth_module

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import android.util.Base64

class MainActivity : FlutterActivity() {
    private val channelName = "xanhnow.smart_otp/device_crypto"
    private val androidKeyStore = "AndroidKeyStore"
    private val keyAlias = "xanhnow_smart_otp_device_key_v1"
    private val appInstanceKey = "xanhnow_smart_otp_app_instance_v1"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "prepareDeviceKey" -> result.success(prepareDeviceKey())
                    "signBinding" -> {
                        val enrollmentId = call.argument<String>("enrollmentId")
                            ?: throw IllegalArgumentException("enrollmentId is required")
                        val externalUserId = call.argument<String>("externalUserId")
                            ?: throw IllegalArgumentException("externalUserId is required")
                        val serverChallenge = call.argument<String>("serverChallenge")
                            ?: throw IllegalArgumentException("serverChallenge is required")
                        val candidatePublicKeyThumbprint = call.argument<String>("candidatePublicKeyThumbprint")
                            ?: throw IllegalArgumentException("candidatePublicKeyThumbprint is required")
                        val appInstanceIdHash = call.argument<String>("appInstanceIdHash")
                            ?: throw IllegalArgumentException("appInstanceIdHash is required")
                        val createdAtUnixMs = call.argument<Number>("createdAtUnixMs")
                            ?: throw IllegalArgumentException("createdAtUnixMs is required")
                        val expiresAtUnixMs = call.argument<Number>("expiresAtUnixMs")
                            ?: throw IllegalArgumentException("expiresAtUnixMs is required")
                        result.success(
                            signBinding(
                                enrollmentId,
                                externalUserId,
                                serverChallenge,
                                candidatePublicKeyThumbprint,
                                appInstanceIdHash,
                                createdAtUnixMs.toLong(),
                                expiresAtUnixMs.toLong(),
                            )
                        )
                    }
                    "signReveal" -> {
                        val challengeId = call.argument<String>("challengeId")
                            ?: throw IllegalArgumentException("challengeId is required")
                        val revealRequestId = call.argument<String>("revealRequestId")
                            ?: throw IllegalArgumentException("revealRequestId is required")
                        val externalUserId = call.argument<String>("externalUserId")
                            ?: throw IllegalArgumentException("externalUserId is required")
                        val deviceId = call.argument<String>("deviceId")
                            ?: throw IllegalArgumentException("deviceId is required")
                        val deviceKeyId = call.argument<String>("deviceKeyId")
                            ?: throw IllegalArgumentException("deviceKeyId is required")
                        val originServiceId = call.argument<String>("originServiceId")
                            ?: throw IllegalArgumentException("originServiceId is required")
                        val purpose = call.argument<String>("purpose")
                            ?: throw IllegalArgumentException("purpose is required")
                        val externalTransactionId = call.argument<String>("externalTransactionId")
                            ?: throw IllegalArgumentException("externalTransactionId is required")
                        val transactionDigest = call.argument<String>("transactionDigest")
                            ?: throw IllegalArgumentException("transactionDigest is required")
                        val issuedAtUnixMs = call.argument<Number>("issuedAtUnixMs")
                            ?: throw IllegalArgumentException("issuedAtUnixMs is required")
                        val proofExpiresAtUnixMs = call.argument<Number>("proofExpiresAtUnixMs")
                            ?: throw IllegalArgumentException("proofExpiresAtUnixMs is required")
                        result.success(
                            signReveal(
                                challengeId,
                                revealRequestId,
                                externalUserId,
                                deviceId,
                                deviceKeyId,
                                originServiceId,
                                purpose,
                                externalTransactionId,
                                transactionDigest,
                                issuedAtUnixMs.toLong(),
                                proofExpiresAtUnixMs.toLong(),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("SMART_OTP_DEVICE_CRYPTO_FAILED", error.message, null)
            }
        }
    }

    private fun prepareDeviceKey(): Map<String, String> {
        val publicKey = ensureKeyPair()
        val publicKeySpki = publicKey.encoded
        val appInstanceHash = sha256(appInstanceId())

        return mapOf(
            "keyAlgorithm" to "ECDSA_P256_SHA256",
            "appInstanceIdHash" to b64(appInstanceHash),
            "candidatePublicKeySpki" to b64(publicKeySpki),
            "candidatePublicKeyThumbprint" to b64(sha256(publicKeySpki)),
        )
    }

    private fun signBinding(
        enrollmentId: String,
        externalUserId: String,
        serverChallenge: String,
        candidatePublicKeyThumbprint: String,
        appInstanceIdHash: String,
        createdAtUnixMs: Long,
        expiresAtUnixMs: Long,
    ): Map<String, String> {
        ensureKeyPair()
        val keyStore = KeyStore.getInstance(androidKeyStore).apply { load(null) }
        val privateKey = keyStore.getKey(keyAlias, null)
            ?: throw IllegalStateException("Smart OTP private key was not found")

        val clientNonce = ByteArray(32)
        SecureRandom().nextBytes(clientNonce)
        val clientNonceBase64 = b64(clientNonce)
        val payload = listOf(
            "xanhnow.smart-otp.binding.v1",
            enrollmentId,
            externalUserId,
            serverChallenge,
            candidatePublicKeyThumbprint,
            appInstanceIdHash,
            clientNonceBase64,
            createdAtUnixMs.toString(),
            expiresAtUnixMs.toString(),
        ).joinToString("\n")

        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey as java.security.PrivateKey)
        signature.update(payload.toByteArray(Charsets.UTF_8))

        return mapOf(
            "clientNonce" to clientNonceBase64,
            "deviceSignature" to b64(signature.sign()),
        )
    }

    private fun signReveal(
        challengeId: String,
        revealRequestId: String,
        externalUserId: String,
        deviceId: String,
        deviceKeyId: String,
        originServiceId: String,
        purpose: String,
        externalTransactionId: String,
        transactionDigest: String,
        issuedAtUnixMs: Long,
        proofExpiresAtUnixMs: Long,
    ): Map<String, String> {
        ensureKeyPair()
        val keyStore = KeyStore.getInstance(androidKeyStore).apply { load(null) }
        val privateKey = keyStore.getKey(keyAlias, null)
            ?: throw IllegalStateException("Smart OTP private key was not found")

        val payload = listOf(
            "xanhnow.smart-otp.reveal.v1",
            challengeId,
            revealRequestId,
            externalUserId,
            deviceId,
            deviceKeyId,
            originServiceId,
            purpose,
            externalTransactionId,
            transactionDigest,
            issuedAtUnixMs.toString(),
            proofExpiresAtUnixMs.toString(),
        ).joinToString("\n")

        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey as java.security.PrivateKey)
        signature.update(payload.toByteArray(Charsets.UTF_8))

        return mapOf("deviceSignature" to b64(signature.sign()))
    }

    private fun ensureKeyPair(): java.security.PublicKey {
        val keyStore = KeyStore.getInstance(androidKeyStore).apply { load(null) }
        keyStore.getCertificate(keyAlias)?.publicKey?.let { return it }

        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            androidKeyStore,
        )
        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .build()

        generator.initialize(spec)
        return generator.generateKeyPair().public
    }

    private fun appInstanceId(): ByteArray {
        val prefs = getSharedPreferences("xanhnow_smart_otp", Context.MODE_PRIVATE)
        val existing = prefs.getString(appInstanceKey, null)
        if (!existing.isNullOrBlank()) {
            return Base64.decode(existing, Base64.NO_WRAP)
        }

        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        prefs.edit().putString(appInstanceKey, b64(bytes)).apply()
        return bytes
    }

    private fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)

    private fun b64(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.NO_WRAP)
}
