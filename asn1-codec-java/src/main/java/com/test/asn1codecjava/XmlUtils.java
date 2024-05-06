package com.test.asn1codecjava;

import lombok.extern.slf4j.Slf4j;
import org.dom4j.Document;
import org.dom4j.DocumentHelper;
import org.dom4j.Node;
import org.dom4j.io.OutputFormat;
import org.dom4j.io.SAXReader;
import org.dom4j.io.XMLWriter;

import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.util.List;

@Slf4j
public class XmlUtils {

    public static String extractMessageFrame(String xml) throws Exception {
        // Get MessageFrame from wrapping
        Document doc = DocumentHelper.parseText(xml);
        List<Node> nodes = doc.selectNodes("//MessageFrame");
        if (!nodes.isEmpty()) {
            log.info("Found MessageFrame in XML");
            Node node = nodes.getFirst();
            String nodeXml = prettyPrint(node);
            log.info("MessageFrame: {}", nodeXml);
            return nodeXml;
        } else {
            log.warn("No MessageFrame found in XML, It's probably an error message, returning it unchanged");
            return xml;
        }
    }

    public static String wrapHex(String hex) {
        return String.format(XML_TEMPLATE, hex);
    }

    public static String prettyPrint(Node node)  {
        try {
            OutputFormat format = OutputFormat.createPrettyPrint();
            format.setIndentSize(4);
            format.setSuppressDeclaration(true);
            format.setEncoding(StandardCharsets.UTF_8.name());
            StringWriter sw = new StringWriter();
            XMLWriter writer = new XMLWriter(sw, format);
            writer.write(node);
            return sw.toString();
        } catch (Exception e) {
            return String.format("Error printing XML: %s", e);
        }
    }

    /**
     * Minimal XML template needed by asn1_codec to decode a message
     */
    public static final String XML_TEMPLATE = """
        <OdeAsn1Data>
            <metadata>
                <encodings>
                    <encodings>
                        <elementType>MessageFrame</elementType>
                        <encodingRule>UPER</encodingRule>
                    </encodings>
                </encodings>
                <payloadType>us.dot.its.jpo.ode.model.OdeAsn1Payload</payloadType>
            </metadata>
            <payload>
                <dataType>us.dot.its.jpo.ode.model.OdeHexByteArray</dataType>
                <data>
                    <bytes>%s</bytes>
                </data>
            </payload>
        </OdeAsn1Data>
        """;

}
