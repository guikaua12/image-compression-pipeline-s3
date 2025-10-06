package tech.guilhermekaua.imagepipelines3

import org.springframework.boot.fromApplication
import org.springframework.boot.with


fun main(args: Array<String>) {
    fromApplication<ImagePipelineS3Application>().with(TestcontainersConfiguration::class).run(*args)
}
