//
//  XMPPIQ+OMEMO.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//
#import "XMPPIQ+OMEMO.h"
#import "XMPPIQ+XEP_0060.h"
#import "OMEMOModule.h"

@implementation XMPPIQ (OMEMO)


/**
    <iq from='juliet@capulet.lit' type='set' id='announce1'>
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <publish node='urn:xmpp:omemo:0:devicelist'>
          <item>
            <list xmlns='urn:xmpp:omemo:0'>
              <device id='12345' />
              <device id='4223' />
              <device id='31415' />
            </list>
          </item>
        </publish>
      </pubsub>
    </iq>
 */
+ (XMPPIQ*) omemo_iqForDeviceIds:(NSArray<NSNumber*>*)deviceIds elementId:(nullable NSString*)elementId {
    NSXMLElement *listElement = [NSXMLElement elementWithName:@"list" xmlns:XMLNS_OMEMO];
    [deviceIds enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *device = [NSXMLElement elementWithName:@"device"];
        [device addAttributeWithName:@"id" numberValue:obj];
        [listElement addChild:device];
    }];
    
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
    [item addChild:listElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    [publish addAttributeWithName:@"node" stringValue:XMLNS_OMEMO_DEVICELIST];
    [publish addChild:item];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementId];
    [iq addChild:pubsub];
    
    return iq;
}

/** iq stanza for publishing bundle for device 
 
 <iq from='juliet@capulet.lit' type='set' id='announce2'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <publish node='urn:xmpp:omemo:0:bundles:31415'>
      <item>
        <bundle xmlns='urn:xmpp:omemo:0'>
          <signedPreKeyPublic signedPreKeyId='1'>
            BASE64ENCODED...
          </signedPreKeyPublic>
          <signedPreKeySignature>
            BASE64ENCODED...
          </signedPreKeySignature>
          <identityKey>
            BASE64ENCODED...
          </identityKey>
          <prekeys>
            <preKeyPublic preKeyId='1'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='2'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='3'>
              BASE64ENCODED...
            </preKeyPublic>
            <!-- ... -->
          </prekeys>
        </bundle>
      </item>
    </publish>
  </pubsub>
</iq>
 
 */
+ (XMPPIQ*) omemo_iqBundle:(OMEMOBundle*)bundle
                 elementId:(nullable NSString*)elementId {
    NSXMLElement *signedPreKeyElement = nil;
    if (bundle.signedPreKey.publicKey) {
        signedPreKeyElement = [NSXMLElement elementWithName:@"signedPreKeyPublic" stringValue:[bundle.signedPreKey.publicKey base64EncodedStringWithOptions:0]];
        [signedPreKeyElement addAttributeWithName:@"signedPreKeyId" unsignedIntegerValue:bundle.signedPreKey.preKeyId];
    }
    NSXMLElement *signedPreKeySignatureElement = nil;
    if (bundle.signedPreKey.signature) {
        signedPreKeySignatureElement = [NSXMLElement elementWithName:@"signedPreKeySignature" stringValue:[bundle.signedPreKey.signature base64EncodedStringWithOptions:0]];
    }
    NSXMLElement *identityKeyElement = nil;
    if (bundle.identityKey) {
        identityKeyElement = [NSXMLElement elementWithName:@"identityKey" stringValue:[bundle.identityKey base64EncodedStringWithOptions:0]];
    }
    NSXMLElement *preKeysElement = [NSXMLElement elementWithName:@"prekeys"];
    [bundle.preKeys enumerateObjectsUsingBlock:^(OMEMOPreKey * _Nonnull preKey, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *preKeyElement = [NSXMLElement elementWithName:@"preKeyPublic" stringValue:[preKey.publicKey base64EncodedStringWithOptions:0]];
        [preKeyElement addAttributeWithName:@"preKeyId" unsignedIntegerValue:preKey.preKeyId];
        [preKeysElement addChild:preKeyElement];
    }];
    NSXMLElement *bundleElement = [XMPPElement elementWithName:@"bundle" xmlns:XMLNS_OMEMO];
    if (signedPreKeyElement) {
        [bundleElement addChild:signedPreKeyElement];
    }
    if (signedPreKeySignatureElement) {
        [bundleElement addChild:signedPreKeySignatureElement];
    }
    if (identityKeyElement) {
        [bundleElement addChild:identityKeyElement];
    }
    [bundleElement addChild:preKeysElement];
    NSXMLElement *itemElement = [NSXMLElement elementWithName:@"item"];
    [itemElement addChild:bundleElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    NSString *nodeName = [NSString stringWithFormat:@"%@:%d",XMLNS_OMEMO_BUNDLES,(int)bundle.deviceId];
    [publish addAttributeWithName:@"node" stringValue:nodeName];
    [publish addChild:itemElement];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementId];
    [iq addChild:pubsub];
    return iq;
}


+ (XMPPIQ *) omemo_iqFetchNode:(NSString *)node to:(XMPPJID *)toJID elementId:(nullable NSString*)elementId {
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:toJID elementID:elementId];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *itemsElement = [NSXMLElement elementWithName:@"items"];
    [itemsElement addAttributeWithName:@"node" stringValue:node];
    
    [pubsub addChild:itemsElement];
    [iq addChild:pubsub];
    
    return iq;
}

/**
 * iq stanza for fetching remote bundle
 
 <iq type='get'
    from='romeo@montague.lit'
    to='juliet@capulet.lit'
    id='fetch1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'/>
  </pubsub>
</iq>
 
 */
+ (XMPPIQ*) omemo_iqFetchBundleForDeviceId:(uint32_t)deviceId
                                       jid:(XMPPJID*)jid
                                 elementId:(nullable NSString*)elementId {
    NSString *nodeName = [NSString stringWithFormat:@"%@:%d",XMLNS_OMEMO_BUNDLES,(int)deviceId];
    return [self omemo_iqFetchNode:nodeName to:jid elementId:elementId];
}

/** 
 * iq stanza for fetching devices
 
 <iq type='get'
    from='romeo@montague.lit'
    to='juliet@capulet.lit'
    id='fetch1'>
 <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'/>
 </pubsub>
 </iq>
 
 this should be handled automatically by PEP
+ (XMPPIQ*) omemo_iqFetchDevices:(XMPPJID *)jid
{
    NSString *nodeName = XMLNS_OMEMO_DEVICELIST;
    return [self omemo_iqFetchNode:nodeName to:jid];
}
 */

@end