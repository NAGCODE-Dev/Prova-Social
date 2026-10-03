from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import simpleSplit
from reportlab.pdfgen import canvas


OUTPUT = Path(__file__).with_name("synthetic_two_column_80_questions.pdf")
PAGE_WIDTH, PAGE_HEIGHT = A4
MARGIN = 40
GUTTER = 24
COLUMN_WIDTH = (PAGE_WIDTH - 2 * MARGIN - GUTTER) / 2


def draw_question(pdf: canvas.Canvas, number: int, x: float, top: float) -> float:
    text = (
        f"Questão {number}. Em exercício lógico fictício, aplique "
        f"a transformação 3n + 2 à sequência {number}. "
        f"Qual resultado corresponde a n = {number}?"
    )
    pdf.setFont("Helvetica-Bold", 8.5)
    y = top
    for line in simpleSplit(text, "Helvetica-Bold", 8.5, COLUMN_WIDTH):
        pdf.drawString(x, y, line)
        y -= 10

    answer = 3 * number + 2
    pdf.setFont("Helvetica", 8)
    for label, offset in zip("ABCDE", range(-2, 3)):
        pdf.drawString(x + 8, y, f"{label}) Código {answer + offset:03d}")
        y -= 10
    return y - 12


def main() -> None:
    pdf = canvas.Canvas(str(OUTPUT), pagesize=A4, pageCompression=1)
    pdf.setTitle("Fixture sintética de importação — 80 questões")
    pdf.setAuthor("Prova Social — fixture original de QA")

    for page_index in range(8):
        pdf.setFont("Helvetica-Bold", 11)
        pdf.drawString(MARGIN, PAGE_HEIGHT - 30, "CADERNO SINTÉTICO DE TESTE")
        pdf.setFont("Helvetica", 7.5)
        pdf.drawString(
            MARGIN,
            PAGE_HEIGHT - 43,
            "Não oficial. Conteúdo fictício criado exclusivamente para QA.",
        )

        left_x = MARGIN
        right_x = MARGIN + COLUMN_WIDTH + GUTTER
        pdf.setStrokeColorRGB(0.78, 0.81, 0.79)
        pdf.setLineWidth(0.5)
        pdf.line(
            MARGIN + COLUMN_WIDTH + GUTTER / 2,
            55,
            MARGIN + COLUMN_WIDTH + GUTTER / 2,
            PAGE_HEIGHT - 58,
        )

        first_number = page_index * 10 + 1
        for column_x, start in ((left_x, first_number), (right_x, first_number + 5)):
            y = PAGE_HEIGHT - 68
            for number in range(start, start + 5):
                y = draw_question(pdf, number, column_x, y)

        pdf.setFont("Helvetica", 7)
        pdf.drawCentredString(
            PAGE_WIDTH / 2,
            30,
            "Fixture sintética original do projeto — não representa prova real.",
        )
        pdf.showPage()

    pdf.save()
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
