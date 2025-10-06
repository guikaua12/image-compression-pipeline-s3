package tech.guilhermekaua.imagepipelines3

import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import

@Import(TestcontainersConfiguration::class)
@SpringBootTest
class ImagePipelineS3ApplicationTests {

    @Test
    fun contextLoads() {
    }

}
