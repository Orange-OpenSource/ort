/*
 * Copyright (C) 2022 EPAM Systems, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

package org.ossreviewtoolkit.helper.utils

import java.io.File

import org.ossreviewtoolkit.model.config.PathExclude
import org.ossreviewtoolkit.model.config.PathExcludeReason.BUILD_TOOL_OF
import org.ossreviewtoolkit.model.config.PathExcludeReason.DOCUMENTATION_OF
import org.ossreviewtoolkit.model.config.PathExcludeReason.TEST_OF

/**
 * This class generates path excludes based on the set of file paths present in the source tree.
 */
internal object PathExcludeGenerator {
    /**
     * Return path excludes which likely but not necessarily apply to a source tree containing all given [filePaths]
     * which must be relative to the root directory of the source tree.
     */
    fun generatePathExcludes(filePaths: Set<String>): List<PathExclude> {
        val files = filePaths.mapTo(mutableSetOf()) { File(it) }
        val dirs = getAllDirs(files)

        val pathExcludes = mutableSetOf<PathExclude>()

        dirs.forEach { dir ->
            PATH_EXCLUDES_REASON_FOR_DIR_NAME[dir.name]?.let { reason ->
                pathExcludes += PathExclude(
                    pattern = "${dir.path}/**",
                    reason = reason
                )
            }
        }

        val filesForPathExcludes = pathExcludes.associateWith { pathExcludeExclude ->
            files.filter { pathExcludeExclude.matches(it.path) }.toSet()
        }

        return greedySetCover(filesForPathExcludes).toList()
    }
}

private fun getAllDirs(files: Set<File>): Set<File> {
    val result = mutableSetOf<File>()

    files.forEach { file ->
        var dir = file.parentFile

        while (dir != null) {
            result += dir
            dir = dir.parentFile
        }
    }

    return result
}

private val PATH_EXCLUDES_REASON_FOR_DIR_NAME = mapOf(
    "bench" to TEST_OF,
    "benchmark" to TEST_OF,
    "benchmarks" to TEST_OF,
    "build" to BUILD_TOOL_OF,
    "docs" to DOCUMENTATION_OF,
    "m4" to BUILD_TOOL_OF,
    "test" to TEST_OF,
    "tests" to TEST_OF,
    "tools" to BUILD_TOOL_OF
)