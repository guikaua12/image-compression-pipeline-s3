package tech.guilhermekaua.imagepipelines3

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class ImagePipelineS3Application

fun main(args: Array<String>) {
    runApplication<ImagePipelineS3Application>(*args)
}
