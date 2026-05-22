#include <stdbool.h>
#include <stdint.h>

#include "DNSProtocolWrapper.h"

void DNSProtocolEverParseError(const char *StructName, const char *FieldName, const char *Reason)
{
  (void)StructName;
  (void)FieldName;
  (void)Reason;
}

bool ism_smoke_everparse_header(void)
{
  uint8_t header[12] = {0};
  uint8_t valid_single_answer[] = {
    0x12U, 0x34U,
    0x81U, 0x80U,
    0x00U, 0x01U,
    0x00U, 0x01U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U,
    0x00U, 0x00U, 0x00U, 0x3cU,
    0x00U, 0x04U,
    0x01U, 0x02U, 0x03U, 0x04U
  };
  uint8_t answer_without_question[] = {
    0x12U, 0x34U,
    0x81U, 0x80U,
    0x00U, 0x00U,
    0x00U, 0x01U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U,
    0x00U, 0x00U, 0x00U, 0x3cU,
    0x00U, 0x04U,
    0x01U, 0x02U, 0x03U, 0x04U
  };
  uint8_t two_questions[] = {
    0x12U, 0x38U,
    0x01U, 0x00U,
    0x00U, 0x02U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U,
    0x00U,
    0x00U, 0x1cU,
    0x00U, 0x01U
  };

  return
    DnsprotocolCheckDnsHeader(header, sizeof header) != 0 &&
    DnsprotocolCheckDnsUncompressedQuestionAAnswerPacket(
      1U,
      1U,
      valid_single_answer,
      (uint32_t)sizeof valid_single_answer
    ) != 0 &&
    DnsprotocolCheckDnsUncompressedQuestionAAnswerPacket(
      1U,
      1U,
      answer_without_question,
      (uint32_t)sizeof answer_without_question
    ) == 0 &&
    DnsprotocolCheckDnsUncompressedQuestionAAnswerPacket(
      1U,
      1U,
      two_questions,
      (uint32_t)sizeof two_questions
    ) == 0;
}
