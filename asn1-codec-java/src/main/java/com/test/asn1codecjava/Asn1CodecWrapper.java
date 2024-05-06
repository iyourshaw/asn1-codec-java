package com.test.asn1codecjava;

import lombok.extern.slf4j.Slf4j;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.dom4j.Document;
import org.dom4j.io.SAXReader;
import org.springframework.stereotype.Component;
import org.w3c.dom.Node;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import static com.test.asn1codecjava.XmlUtils.extractMessageFrame;


@Component
@Slf4j
public class Asn1CodecWrapper {


    public String decode(String inputMessage) throws Exception {

        log.info("Decoding message: {}", inputMessage);

        // Wrap hex in ODE XML:
        String xml = XmlUtils.wrapHex(inputMessage);

        log.info("XML: {}", xml);

        // Save XML to temp file
        String tempDir = FileUtils.getTempDirectoryPath();
        String tempFileName = "asn1-codec-java-" + UUID.randomUUID().toString() + ".xml";
        log.info("Temp file name: {}", tempFileName);
        Path tempFilePath = Path.of(tempDir, tempFileName);
        File tempFile = new File(tempFilePath.toString());
        FileUtils.writeStringToFile(tempFile, xml, StandardCharsets.UTF_8);

        // Run ACM tool to decode message
        var pb = new ProcessBuilder(
                "/build/acm", "-F", "-c", "/build/config/example.properties", "-T", "decode", tempFile.getAbsolutePath());
        pb.directory(new File("/build"));
        Process process = pb.start();
        String result = IOUtils.toString(process.getInputStream(), StandardCharsets.UTF_8);
        log.info("Result: {}", result);

        // Clean up temp file
        tempFile.delete();

        // Remove wrapping from result to just return the XER
        try {
            String messageFrame = extractMessageFrame(result);
            log.info("Message frame: {}", messageFrame);
            return messageFrame;
        } catch (Exception e) {
            log.error("Error extracting message frame: {}, returning result which is probably an error message", e);
            return result;
        }
    }





}
