/*
 * Copyright (c) 2026 Taner Sener
 *
 * This file is part of FFmpegKitNext.
 *
 * FFmpegKitNext is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKitNext is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General License for more details.
 *
 * You should have received a copy of the GNU Lesser General License
 * along with FFmpegKitNext. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * embind bindings that expose the FFmpegKitNext C++ API to JavaScript. Compiled
 * into libffmpegkit and linked into the FFmpegKitModule main module. Registration
 * runs from static initializers; see the anchor at the bottom for how it is kept
 * alive under MAIN_MODULE=2 dead-code elimination.
 *
 * Scope (v1): synchronous execution, sessions, value types, enums and config.
 * The worker host runs execute() synchronously and drains logs/statistics from the
 * session on completion, so live log/statistics callbacks are intentionally NOT
 * bound here yet — see the DEFERRED note near enableLogCallback below.
 *
 * Also bound: the ffkitmem:/ffkitstream: I/O classes (FFmpegKitInputBuffer,
 * FFmpegKitOutputBuffer, FFmpegKitStreamInput, FFmpegKitStreamOutput). The streams
 * block on condition variables in FFmpegKitConfig, which compile to Atomics.wait —
 * legal only off the main browser thread. The intended topology is executeAsync()
 * (which runs FFmpeg on its own pthread and returns immediately), leaving the host
 * worker free to pump write()/read() against the shared-memory ring. Callers stuck
 * on the main thread must instead poll with timeoutMs == 0 (non-blocking).
 */

#include <emscripten/bind.h>
#include <emscripten/emscripten.h>
#include <emscripten/val.h>

#include <cstdint>
#include <list>
#include <memory>
#include <string>
#include <vector>

#include "Chapter.h"
#include "FFmpegKit.h"
#include "FFmpegKitConfig.h"
#include "FFmpegKitInputBuffer.h"
#include "FFmpegKitOutputBuffer.h"
#include "FFmpegKitStreamInput.h"
#include "FFmpegKitStreamOutput.h"
#include "FFmpegSession.h"
#include "FFprobeKit.h"
#include "FFprobeSession.h"
#include "Level.h"
#include "Log.h"
#include "LogRedirectionStrategy.h"
#include "MediaInformation.h"
#include "MediaInformationSession.h"
#include "ReturnCode.h"
#include "SessionState.h"
#include "Statistics.h"
#include "StreamInformation.h"

using namespace emscripten;
using namespace ffmpegkit;

namespace {

// ---------------------------------------------------------------------------
// Small conversion helpers. The C++ API returns std::shared_ptr<std::string> /
// std::shared_ptr<int64_t> for "nullable" values and std::list / std::vector of
// shared_ptr for collections; embind does not marshal those directly, so we
// convert them to JS strings/numbers/arrays (or null) here.
// ---------------------------------------------------------------------------

val optString(const std::shared_ptr<std::string> &value) {
    return value ? val(*value) : val::null();
}

val optInt64(const std::shared_ptr<std::int64_t> &value) {
    return value ? val(static_cast<double>(*value)) : val::null();
}

template <typename T>
val listToArray(const std::shared_ptr<std::list<std::shared_ptr<T>>> &items) {
    val array = val::array();
    if (items) {
        int index = 0;
        for (const auto &item : *items) {
            array.set(index++, item);
        }
    }
    return array;
}

template <typename T>
val vectorToArray(const std::shared_ptr<std::vector<std::shared_ptr<T>>> &items) {
    val array = val::array();
    if (items) {
        int index = 0;
        for (const auto &item : *items) {
            array.set(index++, item);
        }
    }
    return array;
}

// ---- Session accessors that return collections (bound as methods) ----------

val session_getAllLogs(AbstractSession &self) { return listToArray(self.getAllLogs()); }
val session_getLogs(AbstractSession &self) { return listToArray(self.getLogs()); }
val ffmpegSession_getStatistics(FFmpegSession &self) { return listToArray(self.getStatistics()); }
val ffmpegSession_getAllStatistics(FFmpegSession &self) { return listToArray(self.getAllStatistics()); }

// ---- FFmpegKit / FFprobeKit statics -----------------------------------------
// Free wrappers avoid embind overload-resolution issues (execute/cancel are
// overloaded on the C++ side) and keep the async overloads out of v1.

std::shared_ptr<FFmpegSession> ffmpegKit_execute(const std::string command) {
    return FFmpegKit::execute(command);
}

// Starts the command on a worker thread and returns the session immediately, so
// the JS host thread stays free to service emscripten's on-demand pthread
// creation (FFmpeg spawns more threads than the prewarmed pool). The JS side
// observes completion by polling the session state; the completion callback is a
// no-op here because delivering it to JS would require cross-thread val proxying.
std::shared_ptr<FFmpegSession> ffmpegKit_executeAsync(const std::string command) {
    return FFmpegKit::executeAsync(
        command, [](std::shared_ptr<ffmpegkit::FFmpegSession>) {});
}
void ffmpegKit_cancel() { FFmpegKit::cancel(); }
void ffmpegKit_cancelSession(const long sessionId) { FFmpegKit::cancel(sessionId); }
val ffmpegKit_listSessions() { return listToArray(FFmpegKit::listSessions()); }

std::shared_ptr<FFprobeSession> ffprobeKit_execute(const std::string command) {
    return FFprobeKit::execute(command);
}
std::shared_ptr<MediaInformationSession>
ffprobeKit_getMediaInformation(const std::string path) {
    return FFprobeKit::getMediaInformation(path);
}

// ---- MediaInformation / StreamInformation accessors -------------------------
// Bound as methods; convert the nullable shared_ptr<string>/<int64_t> results.

val mediaInformation_getFilename(MediaInformation &self) { return optString(self.getFilename()); }
val mediaInformation_getFormat(MediaInformation &self) { return optString(self.getFormat()); }
val mediaInformation_getLongFormat(MediaInformation &self) { return optString(self.getLongFormat()); }
val mediaInformation_getDuration(MediaInformation &self) { return optString(self.getDuration()); }
val mediaInformation_getStartTime(MediaInformation &self) { return optString(self.getStartTime()); }
val mediaInformation_getSize(MediaInformation &self) { return optString(self.getSize()); }
val mediaInformation_getBitrate(MediaInformation &self) { return optString(self.getBitrate()); }
val mediaInformation_getStreams(MediaInformation &self) { return vectorToArray(self.getStreams()); }
val mediaInformation_getChapters(MediaInformation &self) { return vectorToArray(self.getChapters()); }

val streamInformation_getIndex(StreamInformation &self) { return optInt64(self.getIndex()); }
val streamInformation_getType(StreamInformation &self) { return optString(self.getType()); }
val streamInformation_getCodec(StreamInformation &self) { return optString(self.getCodec()); }
val streamInformation_getCodecLong(StreamInformation &self) { return optString(self.getCodecLong()); }
val streamInformation_getFormat(StreamInformation &self) { return optString(self.getFormat()); }
val streamInformation_getWidth(StreamInformation &self) { return optInt64(self.getWidth()); }
val streamInformation_getHeight(StreamInformation &self) { return optInt64(self.getHeight()); }
val streamInformation_getBitrate(StreamInformation &self) { return optString(self.getBitrate()); }
val streamInformation_getSampleRate(StreamInformation &self) { return optString(self.getSampleRate()); }
val streamInformation_getChannelLayout(StreamInformation &self) { return optString(self.getChannelLayout()); }

// ---- Byte marshaling --------------------------------------------------------
// embind's default std::vector<uint8_t> conversion marshals element-by-element,
// which dominates transfer time for media payloads. These helpers do a single
// bulk copy through a heap-backed typed-array view instead.

// Copies a JS byte source (Uint8Array or any TypedArray/array-like with a numeric
// "length") into a std::vector<uint8_t> with one TypedArray.set into a heap view.
std::vector<uint8_t> toByteVector(const val &data) {
    const size_t length = data["length"].as<size_t>();
    std::vector<uint8_t> bytes(length);
    if (length > 0) {
        val view = val(typed_memory_view(length, bytes.data()));
        view.call<void>("set", data);
    }
    return bytes;
}

// Copies raw bytes out into a fresh, JS-owned Uint8Array. The heap view aliases
// C++ memory that is freed on return, so the copy (via TypedArray.set) must happen
// before this returns — which it does, synchronously, with no allocation between.
val toUint8Array(const std::vector<uint8_t> &data) {
    val result = val::global("Uint8Array").new_(data.size());
    if (!data.empty()) {
        val view = val(typed_memory_view(data.size(), data.data()));
        result.call<void>("set", view);
    }
    return result;
}

// ---- ffkitmem: / ffkitstream: I/O -------------------------------------------
// Private constructors + overloaded factories/writers, so (like execute/cancel)
// each is exposed through a fixed-arity free wrapper. timeoutMs: -1 blocks (only
// legal off the main thread), 0 is non-blocking, > 0 is a timed wait.

std::shared_ptr<FFmpegKitInputBuffer>
inputBuffer_fromByteArray(const val &data, const std::string &extension) {
    std::vector<uint8_t> bytes = toByteVector(data);
    return FFmpegKitInputBuffer::fromBytes(bytes.data(), bytes.size(), extension);
}

std::shared_ptr<FFmpegKitOutputBuffer>
outputBuffer_create(const std::string &extension) {
    return FFmpegKitOutputBuffer::create(extension);
}
std::shared_ptr<FFmpegKitOutputBuffer>
outputBuffer_createWithCapacity(const std::string &extension,
                                const long initialCapacity,
                                const long maxCapacity) {
    return FFmpegKitOutputBuffer::create(extension, initialCapacity, maxCapacity);
}
val outputBuffer_toByteArray(FFmpegKitOutputBuffer &self) {
    return toUint8Array(*self.toByteArray());
}

std::shared_ptr<FFmpegKitStreamInput>
streamInput_create(const std::string &extension) {
    return FFmpegKitStreamInput::create(extension);
}
std::shared_ptr<FFmpegKitStreamInput>
streamInput_createWithCapacity(const std::string &extension,
                               const long capacity) {
    return FFmpegKitStreamInput::create(extension, capacity);
}
// Returns the number of bytes accepted into the ring (may be a short write when
// timeoutMs elapses with the ring full).
int streamInput_write(FFmpegKitStreamInput &self, const val &data,
                      const int timeoutMs) {
    std::vector<uint8_t> bytes = toByteVector(data);
    return self.write(bytes.data(), bytes.size(), timeoutMs);
}

std::shared_ptr<FFmpegKitStreamOutput>
streamOutput_create(const std::string &extension) {
    return FFmpegKitStreamOutput::create(extension);
}
std::shared_ptr<FFmpegKitStreamOutput>
streamOutput_createWithCapacity(const std::string &extension,
                                const long capacity) {
    return FFmpegKitStreamOutput::create(extension, capacity);
}
// Tri-state result: null == timed out (retry), empty Uint8Array == EOF/closed,
// non-empty == data read.
val streamOutput_read(FFmpegKitStreamOutput &self, const int maxBytes,
                      const int timeoutMs) {
    auto result = self.read(maxBytes, timeoutMs);
    if (result == nullptr) {
        return val::null();
    }
    return toUint8Array(*result);
}

val chapter_getId(Chapter &self) { return optInt64(self.getId()); }
val chapter_getStart(Chapter &self) { return optInt64(self.getStart()); }
val chapter_getStartTime(Chapter &self) { return optString(self.getStartTime()); }
val chapter_getEnd(Chapter &self) { return optInt64(self.getEnd()); }
val chapter_getEndTime(Chapter &self) { return optString(self.getEndTime()); }

} // namespace

EMSCRIPTEN_BINDINGS(ffmpegkit_bindings) {

    // ---- Enums --------------------------------------------------------------
    enum_<SessionState>("SessionState")
        .value("Created", SessionStateCreated)
        .value("Running", SessionStateRunning)
        .value("Failed", SessionStateFailed)
        .value("Completed", SessionStateCompleted);

    enum_<Level>("Level")
        .value("AVLogStdErr", LevelAVLogStdErr)
        .value("AVLogQuiet", LevelAVLogQuiet)
        .value("AVLogPanic", LevelAVLogPanic)
        .value("AVLogFatal", LevelAVLogFatal)
        .value("AVLogError", LevelAVLogError)
        .value("AVLogWarning", LevelAVLogWarning)
        .value("AVLogInfo", LevelAVLogInfo)
        .value("AVLogVerbose", LevelAVLogVerbose)
        .value("AVLogDebug", LevelAVLogDebug)
        .value("AVLogTrace", LevelAVLogTrace);

    enum_<LogRedirectionStrategy>("LogRedirectionStrategy")
        .value("AlwaysPrintLogs", LogRedirectionStrategyAlwaysPrintLogs)
        .value("PrintLogsWhenNoCallbacksDefined", LogRedirectionStrategyPrintLogsWhenNoCallbacksDefined)
        .value("PrintLogsWhenGlobalCallbackNotDefined", LogRedirectionStrategyPrintLogsWhenGlobalCallbackNotDefined)
        .value("PrintLogsWhenSessionCallbackNotDefined", LogRedirectionStrategyPrintLogsWhenSessionCallbackNotDefined)
        .value("NeverPrintLogs", LogRedirectionStrategyNeverPrintLogs);

    // ---- Value types --------------------------------------------------------
    class_<ReturnCode>("ReturnCode")
        .smart_ptr<std::shared_ptr<ReturnCode>>("shared_ptr<ReturnCode>")
        .function("getValue", &ReturnCode::getValue)
        .function("isValueSuccess", &ReturnCode::isValueSuccess)
        .function("isValueError", &ReturnCode::isValueError)
        .function("isValueCancel", &ReturnCode::isValueCancel);

    class_<Log>("Log")
        .smart_ptr<std::shared_ptr<Log>>("shared_ptr<Log>")
        .function("getSessionId", &Log::getSessionId)
        .function("getLevel", &Log::getLevel)
        .function("getMessage", &Log::getMessage);

    class_<Statistics>("Statistics")
        .smart_ptr<std::shared_ptr<Statistics>>("shared_ptr<Statistics>")
        .function("getSessionId", &Statistics::getSessionId)
        .function("getVideoFrameNumber", &Statistics::getVideoFrameNumber)
        .function("getVideoFps", &Statistics::getVideoFps)
        .function("getVideoQuality", &Statistics::getVideoQuality)
        .function("getSize", &Statistics::getSize)
        .function("getTime", &Statistics::getTime)
        .function("getBitrate", &Statistics::getBitrate)
        .function("getSpeed", &Statistics::getSpeed);

    class_<StreamInformation>("StreamInformation")
        .smart_ptr<std::shared_ptr<StreamInformation>>("shared_ptr<StreamInformation>")
        .function("getIndex", &streamInformation_getIndex)
        .function("getType", &streamInformation_getType)
        .function("getCodec", &streamInformation_getCodec)
        .function("getCodecLong", &streamInformation_getCodecLong)
        .function("getFormat", &streamInformation_getFormat)
        .function("getWidth", &streamInformation_getWidth)
        .function("getHeight", &streamInformation_getHeight)
        .function("getBitrate", &streamInformation_getBitrate)
        .function("getSampleRate", &streamInformation_getSampleRate)
        .function("getChannelLayout", &streamInformation_getChannelLayout);

    class_<Chapter>("Chapter")
        .smart_ptr<std::shared_ptr<Chapter>>("shared_ptr<Chapter>")
        .function("getId", &chapter_getId)
        .function("getStart", &chapter_getStart)
        .function("getStartTime", &chapter_getStartTime)
        .function("getEnd", &chapter_getEnd)
        .function("getEndTime", &chapter_getEndTime);

    class_<MediaInformation>("MediaInformation")
        .smart_ptr<std::shared_ptr<MediaInformation>>("shared_ptr<MediaInformation>")
        .function("getFilename", &mediaInformation_getFilename)
        .function("getFormat", &mediaInformation_getFormat)
        .function("getLongFormat", &mediaInformation_getLongFormat)
        .function("getDuration", &mediaInformation_getDuration)
        .function("getStartTime", &mediaInformation_getStartTime)
        .function("getSize", &mediaInformation_getSize)
        .function("getBitrate", &mediaInformation_getBitrate)
        .function("getStreams", &mediaInformation_getStreams)
        .function("getChapters", &mediaInformation_getChapters);

    // ---- ffkitmem: / ffkitstream: I/O ---------------------------------------
    // Seekable in-memory input: FFmpegKitInputBuffer.fromByteArray(bytes, ext).
    class_<FFmpegKitInputBuffer>("FFmpegKitInputBuffer")
        .smart_ptr<std::shared_ptr<FFmpegKitInputBuffer>>(
            "shared_ptr<FFmpegKitInputBuffer>")
        .class_function("fromByteArray", &inputBuffer_fromByteArray)
        .function("getUrl", &FFmpegKitInputBuffer::getUrl)
        .function("getSize", &FFmpegKitInputBuffer::getSize)
        .function("close", &FFmpegKitInputBuffer::close);

    // Seekable in-memory output: read back with toByteArray() after the command.
    class_<FFmpegKitOutputBuffer>("FFmpegKitOutputBuffer")
        .smart_ptr<std::shared_ptr<FFmpegKitOutputBuffer>>(
            "shared_ptr<FFmpegKitOutputBuffer>")
        .class_function("create", &outputBuffer_create)
        .class_function("createWithCapacity", &outputBuffer_createWithCapacity)
        .function("getUrl", &FFmpegKitOutputBuffer::getUrl)
        .function("getSize", &FFmpegKitOutputBuffer::getSize)
        .function("toByteArray", &outputBuffer_toByteArray)
        .function("close", &FFmpegKitOutputBuffer::close);

    // Non-seekable streaming input: pump write() from the host worker while
    // FFmpeg drains the ring on its own pthread; closeInput() signals EOF.
    class_<FFmpegKitStreamInput>("FFmpegKitStreamInput")
        .smart_ptr<std::shared_ptr<FFmpegKitStreamInput>>(
            "shared_ptr<FFmpegKitStreamInput>")
        .class_function("create", &streamInput_create)
        .class_function("createWithCapacity", &streamInput_createWithCapacity)
        .function("getUrl", &FFmpegKitStreamInput::getUrl)
        .function("write", &streamInput_write)
        .function("closeInput", &FFmpegKitStreamInput::closeInput)
        .function("close", &FFmpegKitStreamInput::close);

    // Non-seekable streaming output: pump read() from the host worker while
    // FFmpeg fills the ring on its own pthread.
    class_<FFmpegKitStreamOutput>("FFmpegKitStreamOutput")
        .smart_ptr<std::shared_ptr<FFmpegKitStreamOutput>>(
            "shared_ptr<FFmpegKitStreamOutput>")
        .class_function("create", &streamOutput_create)
        .class_function("createWithCapacity", &streamOutput_createWithCapacity)
        .function("getUrl", &FFmpegKitStreamOutput::getUrl)
        .function("read", &streamOutput_read)
        .function("close", &FFmpegKitStreamOutput::close);

    // ---- Sessions -----------------------------------------------------------
    // Common accessors live on AbstractSession; subclasses inherit them in JS
    // via base<AbstractSession>.
    class_<AbstractSession>("AbstractSession")
        .smart_ptr<std::shared_ptr<AbstractSession>>("shared_ptr<AbstractSession>")
        .function("getSessionId", &AbstractSession::getSessionId)
        .function("getCommand", &AbstractSession::getCommand)
        .function("getState", &AbstractSession::getState)
        .function("getReturnCode", &AbstractSession::getReturnCode)
        .function("getDuration", &AbstractSession::getDuration)
        .function("getOutput", &AbstractSession::getOutput)
        .function("getAllLogsAsString", &AbstractSession::getAllLogsAsString)
        .function("getLogsAsString", &AbstractSession::getLogsAsString)
        .function("getFailStackTrace", &AbstractSession::getFailStackTrace)
        .function("isFFmpeg", &AbstractSession::isFFmpeg)
        .function("isFFprobe", &AbstractSession::isFFprobe)
        .function("isMediaInformation", &AbstractSession::isMediaInformation)
        .function("cancel", &AbstractSession::cancel)
        .function("getAllLogs", &session_getAllLogs)
        .function("getLogs", &session_getLogs);

    class_<FFmpegSession, base<AbstractSession>>("FFmpegSession")
        .smart_ptr<std::shared_ptr<FFmpegSession>>("shared_ptr<FFmpegSession>")
        .function("getStatistics", &ffmpegSession_getStatistics)
        .function("getAllStatistics", &ffmpegSession_getAllStatistics)
        .function("getLastReceivedStatistics", &FFmpegSession::getLastReceivedStatistics);

    class_<FFprobeSession, base<AbstractSession>>("FFprobeSession")
        .smart_ptr<std::shared_ptr<FFprobeSession>>("shared_ptr<FFprobeSession>");

    class_<MediaInformationSession, base<AbstractSession>>("MediaInformationSession")
        .smart_ptr<std::shared_ptr<MediaInformationSession>>("shared_ptr<MediaInformationSession>")
        .function("getMediaInformation", &MediaInformationSession::getMediaInformation);

    // ---- Entry points -------------------------------------------------------
    class_<FFmpegKit>("FFmpegKit")
        .class_function("execute", &ffmpegKit_execute)
        .class_function("executeAsync", &ffmpegKit_executeAsync)
        .class_function("cancel", &ffmpegKit_cancel)
        .class_function("cancelSession", &ffmpegKit_cancelSession)
        .class_function("listSessions", &ffmpegKit_listSessions);

    class_<FFprobeKit>("FFprobeKit")
        .class_function("execute", &ffprobeKit_execute)
        .class_function("getMediaInformation", &ffprobeKit_getMediaInformation);

    // DEFERRED (v2): enableLogCallback / enableStatisticsCallback and the
    // executeAsync overloads take C++ std::function callbacks. Bridging those to
    // JS functions requires proxying val invocations to the module's main thread
    // (FFmpeg fires them from worker threads), which the worker host does not yet
    // set up. Live progress is instead read from the session after execute()
    // returns (getStatistics / getAllLogsAsString above).
    class_<FFmpegKitConfig>("FFmpegKitConfig")
        .class_function("setLogLevel", &FFmpegKitConfig::setLogLevel)
        .class_function("getLogLevel", &FFmpegKitConfig::getLogLevel)
        .class_function("getVersion", &FFmpegKitConfig::getVersion)
        .class_function("getFFmpegVersion", &FFmpegKitConfig::getFFmpegVersion)
        .class_function("getBuildDate", &FFmpegKitConfig::getBuildDate);
}

/*
 * DCE anchor. Under -sMAIN_MODULE=2 the linker drops object files whose symbols
 * are never referenced, which would silently strip the EMSCRIPTEN_BINDINGS static
 * initializer above. Keeping one exported symbol in this translation unit forces
 * the object (and therefore the registration) to be retained. The build links
 * libffmpegkit whole; if a future change stops honoring that, reference this from
 * the main-module link or add it to -sEXPORTED_FUNCTIONS.
 */
extern "C" EMSCRIPTEN_KEEPALIVE void ffmpegkit_bindings_anchor(void) {}
